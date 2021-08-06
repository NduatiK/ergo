defmodule Ergo.Parser do
  alias __MODULE__
  alias Ergo.{Context, ParserRefs}

  require Logger

  defmodule CycleError do
    alias __MODULE__

    defexception [:message]

    def exception({{_ref, description, _index, line, col}, %{tracks: tracks}}) do
      message =
        Enum.reduce(
          tracks,
          "Ergo has detected a cycle in #{description} and is aborting parsing at: #{line}:#{col}",
          fn {_ref, description, _index, _line, _col}, msg ->
            msg <> "\n#{description}"
          end
        )

      %CycleError{message: message}
    end
  end

  @moduledoc """
  `Ergo.Parser` contains the Parser record type. Ergo parsers are anonymous functions but we embed
  them in a `Parser` record that can hold arbitrary metadata. The primary use for the metadata is
  the storage of debugging information.
  """
  defstruct [
    type: nil,
    combinator: false,
    parser_fn: nil,
    ref: nil,
    label: "#"
  ]

  @doc ~S"""
  `new/2` creates a new `Parser` from the given parsing function and with the specified metadata.
  """
  def new(type, parser_fn, meta \\ []) when is_atom(type) and is_function(parser_fn) do
    %Parser{type: type, parser_fn: parser_fn, ref: ParserRefs.next_ref()}
    |> Map.merge(Enum.into(meta, %{}))
  end

  @doc ~S"""
  `invoke/2` is the main entry point for the parsing process. It looks up the parser control function within
  the `Context` and uses it to run the given `parser`.

  This indirection allows a different control function to be specified, e.g. by the diagnose entry point
  which can wrap the parser call, while still calling the same parsing function (i.e. we are not introducing
  debugging variants of the parsers that could be subject to different behaviours)
  """

  def invoke(%Parser{} = parser, %Context{invoke_fn: invoke_fn} = ctx) do
    invoke_fn.(parser, ctx)
  end

  @doc ~S"""
  `call/2` invokes the specified parser by calling its parsing function with the specified context having
  first reset the context status.
  """
  def call(%Parser{parser_fn: parser_fn} = parser, %Context{} = ctx) do
    ctx
    |> Context.reset_status()
    |> track_parser(parser)
    |> parser_fn.()
  end

  @doc ~S"""
  `diagnose/2` invokes the specified parser by calling its parsing function with the specific context while
  tracking the progress of the parser. The progress can be retrieved from the `progress` key of the returned
  context.

  ## Examples

      iex> alias Ergo.{Context, Parser}
      iex> import Ergo.{Combinators, Terminals}
      iex> context = Context.new(&Ergo.Parser.diagnose/2, "Hello World")
      iex> parser = many(wc())
      iex> assert %{rules: []} = Parser.invoke(parser, context)
  """
  def diagnose(%Parser{ref: ref, type: type, label: label} = parser, %Context{rules: rules} = ctx) do
    calling_ctx = %{ctx | rules: [{ref, type, label} | rules]}
    with %{status: :ok} = updated_ctx <- Parser.call(parser, calling_ctx) do
      %{updated_ctx | rules: rules}
    end
  end

  @doc ~S"""
  `track_parser` first checks if the parser has already been tracked for the current input index and, if it has,
  raises a `CycleError` to indicate the parser is in a loop. Otherwise it adds the parser at the current index.

  ## Examples

    iex> alias Ergo.{Context, Parser}
    iex> import Ergo.{Terminals, Combinators}
    iex> context = Context.new(&Ergo.Parser.call/2, "Hello World")
    iex> parser = many(char(?H))
    iex> context2 = Parser.track_parser(context, parser)
    iex> assert Context.parser_tracked?(context2, parser.ref)
  """
  def track_parser(%Context{} = ctx, %Parser{ref: ref} = parser) do
    if Context.parser_tracked?(ctx, ref) do
      raise Ergo.Parser.CycleError, context: ctx, parser: parser
    else
      Context.track_parser(ctx, ref)
    end
  end

end
