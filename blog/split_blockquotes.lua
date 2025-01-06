--[[ Pandoc Lua filter to split multiline blockquotes
     into a single blockquote with multiple paragraphs
--]]
function BlockQuote(el)
  local new_paragraphs = {}

  for _, block in ipairs(el.content) do
    if block.t == "Para" or block.t == "Plain" then
      local current_inlines = {}
      for _, inline in ipairs(block.content) do
        if inline.t == "SoftBreak" or inline.t == "LineBreak" or inline.t == "HardBreak" then
          if #current_inlines > 0 then
            table.insert(new_paragraphs, pandoc.Para(current_inlines))
            current_inlines = {}
          end
        else
          table.insert(current_inlines, inline)
        end
      end
      if #current_inlines > 0 then
        table.insert(new_paragraphs, pandoc.Para(current_inlines))
      end
    else
      -- Retain non Para/Plain blocks.
      table.insert(new_paragraphs, block)
    end
  end

  -- Return joined blockquote.
  return pandoc.BlockQuote(new_paragraphs)
end
