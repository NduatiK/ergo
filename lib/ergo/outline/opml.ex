defmodule Ergo.Outline.OPML do
  alias Ergo.Outline.Builder
  require IEx

  def generate_opml(id, events) do
    outline =
      events
      |> Builder.build_from_events()
      |> Builder.walk(&generate_node/2)

    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<opml version=\"2.0\">", "<head>\n", "</head>\n", "<body>\n<outline text=\"#{id}\">\n", outline, "</outline>\n</body>\n</opml>\n"]
  end

  def generate_node(%{event: type, type: parser, label: label, line: line, col: col, depth: depth} = event, :open) do
    input = Map.get(event, :input, "")
    [String.duplicate("  ", depth), "<outline event=\"#{to_string(type)}\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(input), "\">\n"]
  end

  def generate_node(%{depth: depth}, :close) do
    [String.duplicate("  ", depth), "</outline>\n"]
  end

  def generate_node(%{event: type, type: parser, label: label, line: line, col: col, depth: depth} = event, :closed) do
    input = Map.get(event, :input, "")
    [String.duplicate("  ", depth), "<outline event=\"#{to_string(type)}\" line=\"#{line}:#{col}\" parser=\"#{to_string(parser)}\" label=\"#{to_xml_attr_value(label)}\" text=\"", to_xml_attr_value(input), "\" />\n"]
  end

  def to_xml_attr_value(message) do
    message
    |> String.replace(~r/&/, "&amp;")
    |> String.replace(~r/"/, "&quot;")
    |> String.replace(~r/</, "&lt;")
    |> String.replace(~r/>/, "&gt;")
    |> String.replace(~r/[\t\r\n]+/, "—")
    |> String.replace(~r/\v/, "||")
  end

  def text(%{event: :enter, type: type, label: label, line: line, col: col, input: input}) do
    to_xml_attr_value("ENTER L#{line}:#{col} #{type}/#{label} [#{input}]")
  end

  def text(%{event: :leave, type: type, label: label, line: line, col: col}) do
    to_xml_attr_value("LEAVE L#{line}:#{col} #{type}/#{label}")
  end

  def text(%{event: :match, type: type, label: label, line: line, col: col, ast: ast}) do
    to_xml_attr_value("MATCH L#{line}:#{col} #{type}/#{label} [#{inspect(ast)}]")
  end

  def text(%{event: :error, type: type, label: label, line: line, col: col, errors: errors}) do
    to_xml_attr_value("ERROR: L#{line}:#{col} #{type}/#{label} #{inspect(errors)}")
  end

  def text(%{
        event: :event,
        type: type,
        label: label,
        line: line,
        col: col,
        user_event: user_event
      }) do
    to_xml_attr_value("EVENT L#{line}:#{col} #{type}/#{label} #{user_event}")
  end
end
