--- @module 'blink.cmp'

--- We need to know where prompts end
--- the most reliable way to get this information
--- is to listen to terminal escape sequences.
--- We listen for the terminal escape sequence
--- \027]133;B for
--- the end of a prompt and put extmarks at their
--- positions in the buffer.
--- TODO: This needs to go to blink.cmp source
--- since blink.cmp plugins are lazy loaded and we
--- miss the first terminal escape sequences this way.
local nvim_terminal_augroup = vim.api.nvim_create_augroup("blink-cmp-zsh.nvim.terminal", {})
local nvim_terminal_prompt_ns = vim.api.nvim_create_namespace("blink-cmp-zsh.nvim.terminal.prompt")
vim.api.nvim_create_autocmd("TermRequest", {
	group = nvim_terminal_augroup,
	desc = "Mark shell prompts indicated by OSC 133 sequences for navigation",
	callback = function(args)
		if string.match(args.data.sequence, "^\027]133;B") then
			local row, col = table.unpack(args.data.cursor)
			vim.api.nvim_buf_set_extmark(args.buf, nvim_terminal_prompt_ns, row - 1, col, {})
		end
	end,
})

--- @class blink.cmp.Source
local source = {}

function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts
	return self
end

function source:enabled()
	return vim.api.nvim_get_option_value("buftype", { buf = vim.api.nvim_get_current_buf() }) == "terminal"
end

--- Get the path of the currently executed lua script.
---
--- @return string
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

--- Get the shell command in the current line by removing
--- the prompt.
--- We're working exclusively with 1-based indexing in this
--- function. If you see +1/-1 shinanigans in the code below
--- this is to account for the neovim api not being consistent
--- with its 1/0-based indexing.
---
--- @param context blink.cmp.Context
--- @return string|nil
local function get_current_command(context)
	vim.print(vim.inspect(vim.api.nvim_win_get_cursor(0)))
	vim.print(vim.inspect(context.cursor))
	vim.print(vim.inspect(context.line))

	local cursor_row = context.cursor[1]
	local cursor_col = context.cursor[2] + 1
	local line = string.sub(context.line, 1, cursor_col - 1)

	local extmarks = vim.api.nvim_buf_get_extmarks(
		0,
		nvim_terminal_prompt_ns,
		{ cursor_row - 1, cursor_col - 1 },
		{ cursor_row - 1, 0 },
		{ limit = 1 }
	)

	--- If we find no mark for the end of the shell prompt we assume
	--- that the whole line is the current command text.
	if #extmarks < 1 then
		return line
	end

	local prompt_end_mark = extmarks[1]
	local prompt_end_col = prompt_end_mark[3] + 1
	return string.sub(line, prompt_end_col, string.len(line))
end

function source:get_completions(context, callback)
	local current_command = get_current_command(context)
	vim.print(vim.inspect(current_command))

	if current_command == nil then
		callback({
			is_incomplete_forward = true,
			is_incomplete_backward = true,
		})
		return
	end

	vim.system({ "zsh", script_path() .. "/capture.zsh", current_command }, nil, function(result)
		if result.code ~= 0 then
			callback({
				is_incomplete_forward = true,
				is_incomplete_backward = true,
			})
			return
		end

		local lines = vim.split(result.stdout, "\r\n")

		--- @type lsp.CompletionItem[]
		local items = {}

		vim.iter(lines):each(function(line)
			table.insert(items, {
				label = line,
				kind = require("blink.cmp.types").CompletionItemKind.Text,
				insertText = line,
			})
		end)

		callback({
			is_incomplete_forward = true,
			is_incomplete_backward = true,
			items = vim.tbl_values(items),
		})
	end)
end

return source
