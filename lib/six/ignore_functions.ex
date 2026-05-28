defmodule Six.Ignore.Functions do
  @moduledoc false

  Module.register_attribute(__MODULE__, :six, accumulate: true)

  @def_keywords [:def, :defp, :defmacro, :defmacrop]
  @attribute_spacing "\\s+"

  @doc """
  Nullifies coverage for functions tagged with @six :ignore.
  """
  def run(file_stats_list, attribute_name \\ :six) do
    Enum.map(file_stats_list, fn file_stats ->
      process_file(file_stats, attribute_name)
    end)
  end

  defp process_file(%{source: source, coverage: coverage} = file_stats, attribute_name) do
    ranges = find_ignored_ranges(source, attribute_name)

    if ranges == [] do
      file_stats
    else
      new_coverage =
        coverage
        |> Enum.with_index(1)
        |> Enum.map(fn {cov, line_num} ->
          if in_any_range?(line_num, ranges), do: nil, else: cov
        end)

      Six.Stats.recalculate(%{file_stats | coverage: new_coverage})
    end
  end

  @doc """
  Returns function definitions in source order.
  Each entry includes `:module`, `:function`, `:arity`, `:start_line`, `:end_line`, and `:ignored?`.
  """
  def functions(source, attribute_name \\ :six) do
    source
    |> parse_functions(attribute_name)
    |> Enum.map(fn %{
                     module: module,
                     function: function,
                     arity: arity,
                     start_line: start_line,
                     end_line: end_line,
                     ignored?: ignored?
                   } ->
      %{
        module: module,
        function: function,
        arity: arity,
        start_line: start_line,
        end_line: end_line,
        ignored?: ignored?
      }
    end)
  end

  @doc """
  Returns ignored ranges with function names for reporting.
  Returns [%{start_line, end_line, function}].
  """
  def ignored_functions(source, attribute_name \\ :six) do
    source
    |> functions(attribute_name)
    |> Enum.filter(& &1.ignored?)
    |> Enum.map(&Map.delete(&1, :ignored?))
  end

  @doc """
  Parses source code and returns line ranges for functions tagged with the ignore attribute.
  Returns [{start_line, end_line}].
  """
  def find_ignored_ranges(source, attribute_name \\ :six) do
    source
    |> ignored_functions(attribute_name)
    |> Enum.map(fn %{start_line: start_line, end_line: end_line} ->
      {start_line, end_line}
    end)
  end

  defp parse_functions(source, attribute_name) do
    unless String.contains?(source, "@#{attribute_name}") do
      parse_functions_via_ast(source, attribute_name)
    else
      parse_functions_via_ast(source, attribute_name)
    end
  end

  defp parse_functions_via_ast(source, attribute_name) do
    # Suppress diagnostics (e.g. deprecation warnings) emitted while parsing
    # user source for analysis — the compiler already surfaced them at build.
    {parsed, _diagnostics} =
      Code.with_diagnostics(fn ->
        Code.string_to_quoted(source, columns: true, token_metadata: true)
      end)

    case parsed do
      {:ok, ast} ->
        source_lines = String.split(source, "\n")
        scan_ast(ast, attribute_name, source_lines, nil, false, [])

      {:error, _} ->
        parse_functions_via_string(source, attribute_name)
    end
  end

  defp extract_body({:defmodule, _, [_, kwl]}) when is_list(kwl) do
    case Keyword.get(kwl, :do) do
      {:__block__, _, body} when is_list(body) -> body
      nil -> []
      single -> [single]
    end
  end

  @six :ignore
  defp extract_body({:__block__, _, body}) when is_list(body), do: body
  @six :ignore
  defp extract_body(_), do: []

  defp scan_ast(
         {:defmodule, _, [name_ast, kwl]} = expr,
         attr_name,
         source_lines,
         _module,
         _ignore_next,
         acc
       )
       when is_list(kwl) do
    module = module_name(name_ast)
    expr |> extract_body() |> scan_expressions(attr_name, source_lines, module, false, acc)
  end

  defp scan_ast({:__block__, _, body}, attr_name, source_lines, module, ignore_next, acc)
       when is_list(body) do
    scan_expressions(body, attr_name, source_lines, module, ignore_next, acc)
  end

  defp scan_ast(ast, attr_name, source_lines, module, ignore_next, acc) do
    scan_expressions([ast], attr_name, source_lines, module, ignore_next, acc)
  end

  defp scan_expressions([], _attr_name, _source_lines, _module, _ignore_next, acc),
    do: Enum.reverse(acc)

  defp scan_expressions([expr | rest], attr_name, source_lines, module, ignore_next, acc) do
    case expr do
      {:@, _, [{^attr_name, _, [:ignore]}]} ->
        scan_expressions(rest, attr_name, source_lines, module, true, acc)

      {def_type, meta, [head | _]} when def_type in @def_keywords ->
        entry = %{
          module: module,
          function: format_function(def_type, head),
          arity: head_arity(head),
          start_line: meta[:line],
          end_line: find_end_line(meta, source_lines, meta[:line]),
          ignored?: ignore_next
        }

        scan_expressions(rest, attr_name, source_lines, module, false, [entry | acc])

      {:defmodule, _, [name_ast, kwl]} when is_list(kwl) ->
        nested_module = module_name(name_ast)
        inner_body = extract_body(expr)

        inner_entries =
          scan_expressions(inner_body, attr_name, source_lines, nested_module, false, [])

        scan_expressions(
          rest,
          attr_name,
          source_lines,
          module,
          ignore_next,
          Enum.reverse(inner_entries) ++ acc
        )

      _ ->
        if is_module_attribute?(expr) and ignore_next do
          scan_expressions(rest, attr_name, source_lines, module, true, acc)
        else
          scan_expressions(rest, attr_name, source_lines, module, false, acc)
        end
    end
  end

  defp module_name({:__aliases__, _, parts}), do: Module.concat(parts)
  defp module_name(atom) when is_atom(atom), do: atom
  defp module_name(_), do: nil

  defp is_module_attribute?({:@, _, _}), do: true
  defp is_module_attribute?(_), do: false

  defp format_function(def_type, head) do
    case extract_function_name(head) do
      nil -> Atom.to_string(def_type)
      name -> "#{def_type} #{name}"
    end
  end

  defp extract_function_name({:when, _, [call | _guards]}), do: extract_function_name(call)
  defp extract_function_name({name, _, _args}) when is_atom(name), do: Atom.to_string(name)
  defp extract_function_name(_), do: nil

  defp head_arity({:when, _, [call | _guards]}), do: head_arity(call)
  defp head_arity({name, _, args}) when is_atom(name) and is_list(args), do: length(args)
  defp head_arity({name, _, nil}) when is_atom(name), do: 0
  defp head_arity(_), do: nil

  @six :ignore
  defp find_end_line(meta, source_lines, start_line) do
    cond do
      meta[:end] && meta[:end][:line] ->
        meta[:end][:line]

      meta[:end_of_expression] && meta[:end_of_expression][:line] ->
        meta[:end_of_expression][:line]

      true ->
        find_function_end(source_lines, start_line)
    end
  end

  @doc false
  def find_function_end(source_lines, start_line) do
    source_lines
    |> Enum.drop(start_line - 1)
    |> Enum.reduce_while({0, start_line, false}, fn line, {depth, current_line, started} ->
      sanitized = sanitize_line(line)
      opens = count_opens(sanitized)
      closes = count_closes(sanitized)

      new_started = started || opens > 0
      new_depth = if new_started, do: depth + opens - closes, else: depth

      if new_started and new_depth <= 0 and current_line > start_line do
        {:halt, current_line}
      else
        {:cont, {new_depth, current_line + 1, new_started}}
      end
    end)
    |> case do
      {_, _, _} -> start_line
      end_line -> end_line
    end
  end

  defp sanitize_line(line) do
    line
    |> strip_comments()
    |> strip_double_quoted_strings()
    |> strip_single_quoted_strings()
  end

  defp strip_comments(line), do: String.replace(line, ~r/#.*$/, "")

  defp strip_double_quoted_strings(line) do
    String.replace(line, ~r/"(?:[^"\\]|\\.)*"/, "\"\"")
  end

  defp strip_single_quoted_strings(line) do
    String.replace(line, ~r/'(?:[^'\\]|\\.)*'/, "''")
  end

  defp count_opens(line) do
    do_count = length(Regex.scan(~r/\bdo\b(?!:)/, line))
    fn_count = length(Regex.scan(~r/\bfn\b/, line))
    do_count + fn_count
  end

  defp count_closes(line) do
    length(Regex.scan(~r/\bend\b/, line))
  end

  defp in_any_range?(line_num, ranges) do
    Enum.any?(ranges, fn {start_line, end_line} ->
      line_num >= start_line and line_num <= end_line
    end)
  end

  @six :ignore
  defp parse_functions_via_string(source, attribute_name) do
    lines = String.split(source, "\n")
    attr_pattern = ~r/^\s*@#{attribute_name}#{@attribute_spacing}:ignore\s*$/

    lines
    |> Enum.with_index(1)
    |> Enum.reduce({false, []}, fn {line, line_num}, {ignore_next, acc} ->
      cond do
        Regex.match?(attr_pattern, line) ->
          {true, acc}

        ignore_next && Regex.match?(~r/^\s*(def|defp|defmacro|defmacrop)\s+/, line) ->
          def_type = extract_def_type(line)
          function = "#{def_type} #{extract_name_from_line(line)}"
          end_line = find_function_end(lines, line_num)

          {false,
           [
             %{
               module: nil,
               function: function,
               arity: nil,
               start_line: line_num,
               end_line: end_line,
               ignored?: true
             }
             | acc
           ]}

        ignore_next && Regex.match?(~r/^\s*@/, line) ->
          {true, acc}

        true ->
          {false, acc}
      end
    end)
    |> elem(1)
    |> Enum.reverse()
  end

  defp extract_def_type(line) do
    [_, def_type] = Regex.run(~r/^\s*(def|defp|defmacro|defmacrop)\b/, line)
    def_type
  end

  defp extract_name_from_line(line) do
    case Regex.run(~r/^\s*(?:def|defp|defmacro|defmacrop)\s+([[:word:]?!]+)/, line) do
      [_, name] -> name
      _ -> "unknown"
    end
  end
end
