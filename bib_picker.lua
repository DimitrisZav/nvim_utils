local Path = require("plenary.path")

local M = {}

local function get_bibfile()
  local cwd = vim.loop.cwd()
  local files = vim.fn.globpath(cwd, "*.bib", false, true)
  if #files == 0 then
    vim.notify("No .bib file found in project root", vim.log.levels.WARN)
    return nil
  end
  return files[1]
end

local function parse_bib_entry(entry)
  local citekey = entry:match("@%w+%s*{%s*(.-),") or ""
  local title = entry:match('title%s*=%s*[{"](.-)[}"]') or ""
  local author = entry:match('author%s*=%s*[{"](.-)[}"]') or ""
  local year = entry:match('year%s*=%s*[{"](.-)[}"]') or ""
  local entry_type = entry:match("@(%w+)%s*{") or ""
  return {
    citekey = citekey:gsub("%s+", ""),
    title = title,
    author = author,
    year = year,
    type = entry_type,
  }
end

function M.bib_picker()
  local bibfile = get_bibfile()
  if not bibfile then
    return
  end

  local path = Path:new(bibfile)
  local raw = path:read()

  if not raw or raw == "" then
    vim.notify("Failed to read .bib file or file is empty", vim.log.levels.ERROR)
    return
  end

  local entries = {}
  for entry in raw:gmatch("(@%w+%b{})") do
    local fields = parse_bib_entry(entry)
    if fields.citekey ~= "" then
      table.insert(entries, {
        label = string.format("%s | %s | %s", fields.citekey, fields.title, fields.author),
        citekey = fields.citekey,
      })
    end
  end

  if #entries == 0 then
    vim.notify("No entries found in .bib file", vim.log.levels.WARN)
    return
  end

  local selected_set = {}
  local hidden_buf = vim.api.nvim_create_buf(false, true) -- hidden, no file

  local function update_buffer()
    local list = {}
    for key, _ in pairs(selected_set) do
      table.insert(list, "@" .. key)
    end
    local line = "[" .. table.concat(list, ", ") .. "]"
    vim.api.nvim_buf_set_lines(hidden_buf, 0, -1, false, { line })
  end

  local function copy_to_registers()
    local content = vim.api.nvim_buf_get_lines(hidden_buf, 0, -1, false)[1] or ""
    vim.fn.setreg('"', content)
    vim.fn.setreg("+", content)
    vim.fn.setreg("*", content)
    vim.fn.system("echo -n '" .. content:gsub("'", "'\\''") .. "' | pbcopy")
    vim.notify("Copied to clipboard: " .. content)
  end

  local function select_next()
    vim.ui.select(entries, {
      prompt = "Select BibTeX entry (press Esc to finish)",
      format_item = function(item)
        local mark = selected_set[item.citekey] and "[x]" or "[ ]"
        return string.format("%s %s", mark, item.label)
      end,
    }, function(choice)
      if choice then
        if selected_set[choice.citekey] then
          selected_set[choice.citekey] = nil
        else
          selected_set[choice.citekey] = true
        end
        update_buffer()
        select_next()
      else
        copy_to_registers()
      end
    end)
  end

  update_buffer()
  select_next()
end

vim.api.nvim_create_user_command("BibPicker", function()
  M.bib_picker()
end, {})

vim.keymap.set("n", "<leader>sP", function()
  M.bib_picker()
end, { desc = "BibTeX Picker" })

return M
