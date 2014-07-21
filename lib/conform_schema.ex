defmodule Conform.Schema do
  @moduledoc """
  This module is responsible for the handling of schema files.
  """

  @type schema      :: [mappings: [mapping], translations: [translation]]
  @type mapping     :: {atom, [doc: binary, to: binary, datatype: atom, default: term]}
  @type translation :: {atom, fun}

  @doc """
  This exception reflects an issue with the schema
  """
  defmodule SchemaError do
    defexception message: "Invalid schema. Should be a keyword list containing :mappings and :translations keys."
  end

  @doc """
  Get the current app's schema path
  """
  @spec schema_path() :: binary
  def schema_path(),    do: Mix.Project.config |> Keyword.get(:app) |> schema_path
  def schema_path(app), do: Path.join([File.cwd!, "config", "#{app}.schema.exs"])

  @doc """
  Load a schema either by name or from the provided path.
  Used for schema evaluation only.
  """
  @spec load!(binary | atom) :: schema
  def load!(path) when is_binary(path) do
    if path |> File.exists? do
      case path |> Code.eval_file do
        {[mappings: _, translations: _] = schema, _} ->
          schema
        _ ->
          raise SchemaError
      end
    else
      raise SchemaError, message: "Schema at #{path} doesn't exist!"
    end
  end
  def load!(name) when is_atom(name) do
    schema_path(name) |> load!
  end

  @doc """
  Loads a schema either by name or from the provided path. If there
  is a problem parsing the schema, or it doesn't exist, an empty
  default schema is returned. Used for schema evaluation only.
  """
  @spec load(binary | atom) :: schema
  def load(path) when is_binary(path) do
    if path |> File.exists? do
      case path |> Code.eval_file do
        {[mappings: _, translations: _] = schema, _} ->
          schema
        _ ->
          empty
      end
    else
      empty
    end
  end
  def load(name) when is_atom(name) do
    schema_path(name) |> load
  end

  @doc """
  Reads a schema file as quoted terms. This is used for manipulating
  the schema (such as merging, etc.)
  """
  @spec read!(binary | atom) :: schema
  def read!(path) when is_binary(path) do
    if path |> File.exists? do
      case path |> File.read! |> Code.string_to_quoted do
        {:ok, [mappings: _, translations: _] = schema} ->
          schema
        _ ->
          raise SchemaError
      end
    else
      raise SchemaError, message: "Schema at #{path} doesn't exist!"
    end
  end
  def read!(name) when is_atom(name) do
    schema_path(name) |> read!
  end

  @doc """
  Reads a schema file as quoted terms. If there
  is a problem parsing the schema, or it doesn't exist, an empty
  default schema is returned. This is used for manipulating
  the schema (such as merging, etc.)
  """
  @spec read(binary | atom) :: schema
  def read(path) when is_binary(path) do
    if path |> File.exists? do
      case path |> File.read! |> Code.string_to_quoted do
        {:ok, [mappings: _, translations: _] = schema} ->
          schema
        _ ->
          empty
      end
    else
      empty
    end
  end
  def read(name) when is_atom(name) do
    schema_path(name) |> read
  end

  @doc """
  Load the schemas for all dependencies of the current project,
  and merge them into a single schema. Schemas are returned in
  their quoted form.
  """
  @spec coalesce() :: schema
  def coalesce do
    # Get schemas from all dependencies
    proj_config = [build_path: Mix.Project.build_path, umbrella?: Mix.Project.umbrella?]
    # Merge schemas for all deps
    Mix.Dep.loaded([])
    |> Enum.map(fn %Mix.Dep{app: app, opts: opts} ->
         Mix.Project.in_project(app, opts[:path], proj_config, fn _ -> read(app) end)
       end)
    |> Enum.reduce(empty, &merge/2)
  end

  @doc """
  Merges two schemas. Conflicts are resolved by taking the value from `y`.
  Expects the schema to be provided in it's quoted form.
  """
  @spec merge(schema, schema) :: schema
  def merge(x, y) do
    mappings     = merge_mappings(Keyword.get(x, :mappings, []), Keyword.get(y, :mappings, []))
    translations = merge_translations(Keyword.get(x, :translations, []), Keyword.get(y, :translations, []))
    [mappings: mappings, translations: translations]
  end

  @doc """
  Saves a schema to the provided path
  """
  @spec write(schema, binary) :: :ok | {:error, term}
  def write(schema, path) do
    path |> File.write!(schema |> Conform.Schema.stringify)
  end

  @doc """
  Converts a schema in it's quoted form and writes it to
  the provided path
  """
  @spec write_quoted(schema, binary) :: :ok | {:error, term}
  def write_quoted(schema, path) do
    contents = stringify(schema)
    path |> File.write!(contents)
  end

  @doc """
  Converts a schema to a prettified string. Expects the schema
  to be in it's quoted form.
  """
  @spec stringify([term]) :: binary
  def stringify(schema) do
    if schema == Conform.Schema.empty do
      schema
        |> Inspect.Algebra.to_doc(%Inspect.Opts{pretty: true})
        |> Inspect.Algebra.pretty(10)
    else
      Conform.Utils.Code.stringify(schema)
    end
  end

  @doc """
  Convert configuration in Elixir terms to schema format.
  """
  @spec from_config([] | [{atom, term}]) :: [{atom, term}]
  def from_config([]), do: empty
  def from_config(config) when is_list(config) do
    [ mappings:     to_schema(config),
      translations: [] ]
  end

  def empty do
    [ mappings:     [],
      translations: [] ]
  end

  defp to_schema([]),                     do: []
  defp to_schema([{app, settings}|rest]), do: to_schema(app, settings, rest)
  defp to_schema(app, settings, config) do
    mappings = Enum.map(settings, fn {k, v} -> to_mapping("#{app}", k, v) end) |> List.flatten
    mappings ++ to_schema(config)
  end

  defp to_mapping(key, setting, value) do
    case Keyword.keyword?(value) do
      true ->
        for {k, v} <- value, into: [] do
          to_mapping("#{key}.#{setting}", k, v)
        end
      false ->
        datatype = extract_datatype(value)
        setting_name = "#{key}.#{setting}"
        ["#{setting_name}": [
          doc: "Documentation for #{setting_name} goes here.",
          to: setting_name,
          datatype: datatype,
          default:  convert_to_datatype(datatype, value)
        ]]
    end
  end

  defp extract_datatype(v) when is_atom(v),    do: :atom
  defp extract_datatype(v) when is_binary(v),  do: :binary
  defp extract_datatype(v) when is_boolean(v), do: :boolean
  defp extract_datatype(v) when is_integer(v), do: :integer
  defp extract_datatype(v) when is_float(v),   do: :float
  # Default lists to binary, unless it's a charlist
  defp extract_datatype(v) when is_list(v) do 
    case :io_lib.char_list(v) do
      true  -> :charlist
      false -> :binary
    end
  end
  defp extract_datatype(_), do: :binary

  defp convert_to_datatype(:binary, v) when is_binary(v),     do: v
  defp convert_to_datatype(:binary, v) when not is_binary(v), do: nil
  defp convert_to_datatype(_, v), do: v

  defp merge_mappings(new, old) do
    # Iterate over each mapping in new, and add it if it doesn't
    # exist in old, otherwise, do nothing
    new |> Enum.reduce(old, fn {key, mapping}, acc ->
      case acc |> Keyword.get(key) do
        nil -> acc ++ [{key, mapping}]
        _   -> acc
      end
    end)
  end
  defp merge_translations(new, old) do
    # Iterate over each translation in new, and add it if it doesn't
    # exist in old, otherwise, do nothing
    new |> Enum.reduce(old, fn {key, translation}, acc ->
      case acc |> Keyword.get(key) do
        nil -> acc ++ [{key, translation}]
        _   -> acc
      end
    end)
  end

end