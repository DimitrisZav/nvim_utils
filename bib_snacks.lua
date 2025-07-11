local Path = require("plenary.path")
local Snacks = require("snacks")

local M = {}

-- Function that filters out the bib entry fields
local function extract_field(entry, field)
  local patterns = { "(%b{})", "(%b[])", '(%b"")' }
  for _, p in ipairs(patterns) do
    local val = entry:match(field .. "%s-=%s-" .. p)
    if val then
      return val:sub(2, -2) -- remove the outer delimiters
    end
  end
  return ""
end
--- Helper to remove nested braces from .bib fields like title or abstract
local function clean_field(str)
  if not str then
    return ""
  end
  return str:gsub("[{}]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Parse a single bib entry into fields
local function parse_bib_entry(entry)
  return {

    citekey = entry:match("@%w+%s*{%s*(.-),") or "",
    -- title = clean_field(entry:match('title%s*=%s*[{"](.-)[}"]')) or "",
    -- The folowing is better for the case where title is enclosed in many braces
    title = clean_field(extract_field(entry, "title")),
    -- author = clean_field(entry:match('author%s*=%s*[{"](.-)[}"]')) or "",
    -- In the rare accoasion where author is enclosed in braces for example:
    --{Coronado-Bl{\'a}zquez} we use the following
    author = clean_field(extract_field(entry, "author")),
    year = entry:match('year%s*=%s*[{"](.-)[}"]') or "",
    abstract = clean_field(extract_field(entry, "abstract")),
    entry_type = entry:match("@(%w+)%s*{") or "",
    -- citekey = entry:match("@%w+%s*{%s*(.-),") or "",
    -- title = clean_field(entry:match('title%s*=%s*[%[{"](.-)[%]}"],?')),
    -- author = clean_field(entry:match('author%s*=%s*[%[{"](.-)[%]}"],?')),
  }
end

--- Reads first .bib file in current working directory
local function read_bib_file()
  local cwd = vim.loop.cwd()
  local bibfiles = vim.fn.globpath(cwd, "*.bib", false, true)
  if #bibfiles == 0 then
    vim.notify("No .bib file found in project root", vim.log.levels.WARN)
    return nil
  end
  local path = Path:new(bibfiles[1])
  return path:read()
end

--- Main BibTeX picker function
function M.bib_picker()
  local raw = read_bib_file()
  if not raw then
    return
  end

  local entries = {}
  for entry in raw:gmatch("@%w+%b{}") do
    local data = parse_bib_entry(entry)
    if data.citekey ~= "" then
      table.insert(entries, {
        text = data.title .. " | " .. data.author,
        data = data,
        preview = {
          title = "Abstract",
          content = data.abstract or "No abstract available.",
        },
      })
    end
  end

  if #entries == 0 then
    vim.notify("No entries found in .bib file", vim.log.levels.WARN)
    return
  end

  Snacks.picker.pick({
    title = "BibTeX Entries",
    format = function(item)
      return {
        -- { item.data.citekey .. " ", "Identifier" },
        { item.idx .. ": " .. item.data.title .. " | " .. item.data.author },
      }
    end,
    preview = "preview",
    finder = function()
      return entries
    end,
    -- preview = function(ctx)
    --   if ctx.item.data.abstract then
    --     Snacks.picker.preview(ctx.item.data.abstract)
    --   else
    --     ctx.preview:reset()
    --     ctx.preview:set_title("No abstract")
    --   end
    --   --   ctx.preview:reset()
    --   --   ctx.preview:set_title("Abstract")
    --   --
    --   --   local abstract = ctx.item.data.abstract or "No abstract available."
    --   --   local lines = vim.split(abstract, "\n", { trimempty = true })
    --   --
    --   --   ctx.preview:append(lines)
    --   --   -- local abstract = ctx.item.data.abstract
    --   --   -- if abstract and abstract ~= "" then
    --   --   --   ctx.preview:reset()
    --   --   --   ctx.preview:append_line(abstract)
    --   --   --   ctx.preview:set_title("Abstract")
    --   --   -- else
    --   --   --   ctx.preview:reset()
    --   --   --   ctx.preview:append_line("No abstract available.")
    --   --   --   ctx.preview:set_title("Preview")
    --   --   -- end
    -- end,
    confirm = function(picker, item)
      picker:close()
      local citation = "@" .. item.data.citekey
      vim.fn.setreg("+", citation)
      vim.fn.setreg("*", citation)
      vim.fn.setreg('"', citation)
      vim.notify("Copied to clipboard: " .. citation)
    end,
  })
end

vim.api.nvim_create_user_command("BibPicker", M.bib_picker, {})
vim.keymap.set("n", "<leader>sB", M.bib_picker, { desc = "BibTeX Picker" })

return M
