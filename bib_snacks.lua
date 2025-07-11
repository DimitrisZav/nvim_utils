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
-- Remove , beteen authors names and replace it with space
local function normalize_author_name(name)
  local last, first = name:match("^(.-),%s*(.+)$")
  if first and last then
    return first .. " " .. last
  else
    return name
  end
end
-- Cut the and from the authors and add et al. if they are too many.
local function shorten_authors(authors)
  local author_list = vim.split(authors, " and ")

  for i, name in ipairs(author_list) do
    author_list[i] = normalize_author_name(name)
  end
  -- If more than 5 authors, shorten to "First Author et al."
  if #author_list > 5 then
    return author_list[1] .. " et al."
  else
    return table.concat(author_list, ", ")
  end
end
local function get_abstract_text(entry)
  if entry.abstract == "" or not entry.abstract then
    return "No abstract available."
  end
  return entry.abstract
end
local function make_preview(entry)
  return {
    text = table.concat({
      "Title: " .. (entry.title or "N/A"),
      "Author: " .. (entry.author or "N/A"),
      "Year: " .. (entry.year or "N/A"),
      "",
      "Abstract:",
      get_abstract_text(entry),
    }, "\n"),
    ft = "markdown", -- optional
  }
end

-- get the bib file
local function get_bibfile()
  -- 1. Try to find .bib near the current file
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path == "" then
    vim.notify("No active buffer", vim.log.levels.WARN)
    return nil
  end

  local current_dir = Path:new(buf_path):parent().filename
  local local_bibs = vim.fn.globpath(current_dir, "*.bib", false, true)

  if #local_bibs > 0 then
    return local_bibs[1]
  end

  -- 2. Try to find .bib in root of project (via cwd or git root)
  local cwd = vim.loop.cwd()
  local project_bibs = vim.fn.globpath(cwd, "*.bib", false, true)
  if #project_bibs > 0 then
    return project_bibs[1]
  end

  -- 3. Nothing found
  vim.notify("No .bib file found", vim.log.levels.WARN)
  return nil
end
--- Reads the .bib file that get_bibfile returns
local function read_bib_file()
  local cwd = vim.loop.cwd()
  -- local bibfiles = vim.fn.globpath(cwd, "*.bib", false, true)
  -- if #bibfiles == 0 then
  --   vim.notify("No .bib file found in project root", vim.log.levels.WARN)
  --   return nil
  -- end
  -- local path = Path:new(bibfiles[1])
  -- Use the better bib_file locator function.
  local bibfiles = get_bibfile()
  -- Check if it exists, so that we do not read a nil directory
  if not bibfiles then
    return nil
  end
  local path = Path:new(bibfiles)
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
        text = data.citekey .. " " .. data.title .. " " .. data.author,
        data = data,
        preview = make_preview(data),
        -- preview = {
        --   text = data.abstract or "No abstract available.",
        -- },
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
        { item.idx .. ": " .. item.data.title .. " | " .. shorten_authors(item.data.author) },
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
      -- local citation = "@" .. item.data.citekey -- I use the following in latex

      local citation = "\\cite{" .. item.data.citekey .. "}"
      vim.fn.setreg("+", citation)
      vim.fn.setreg("*", citation)
      vim.fn.setreg('"', citation)
      vim.notify("Copied to clipboard: " .. citation)
    end,
    layout = {
      layout = {
        backdrop = false,
        width = 0.8,
        min_width = 80,
        height = 0.8,
        min_height = 30,
        box = "vertical",
        border = "rounded",
        title = "{title} {live} {flags}",
        title_pos = "center",
        { win = "input", height = 1, border = "bottom" },
        { win = "list", border = "none" },
        { win = "preview", title = "{preview}", height = 0.4, border = "top" },
      },
    },
    -- win_options = {
    --   winhighlight = {
    --     Normal = "Normal",
    --     FloatBorder = "FloatBorder",
    --     PreviewBorder = "FloatBorder",
    --   },
    -- },
    -- win = { preview = { "minimal" } },
  })
end

vim.api.nvim_create_user_command("BibPicker", M.bib_picker, {})
vim.keymap.set("n", "<leader>sB", M.bib_picker, { desc = "BibTeX Picker" })

return M
