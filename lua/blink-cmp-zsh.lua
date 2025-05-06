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
			local row, col = unpack(args.data.cursor)
			vim.api.nvim_buf_set_extmark(args.buf, nvim_terminal_prompt_ns, row - 1, col, {})
		end
	end,
})

--- @module 'blink.cmp'
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

local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*/)")
end

local function get_current_command(context)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local extmarks = vim.api.nvim_buf_get_extmarks(0, nvim_terminal_prompt_ns, { row - 1, col }, 0, { limit = 1 })

	if #extmarks == 1 then
		local prompt_end_mark = unpack(extmarks)
		local cursor_row, cursor_col = unpack(context.cursor)

		if cursor_row - 1 == prompt_end_mark[2] then
			return string.sub(context.line, prompt_end_mark[3] + 1, string.len(context.line))
		end
	end
end

function source:get_completions(context, callback)
	-- ctx (context) contains the current keyword, cursor position, bufnr, etc.

	local current_command = get_current_command(context)

	if current_command == nil or string.len(current_command) == 0 then
		resolve()
		return
	end

	vim.system(
		{ "zsh", script_path() .. "/capture.zsh", current_command },
		nil,
		function(result)
			if result.code ~= 0 then
				callback()
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
		end
	)
end

function source:execute(ctx, item, callback, default_implementation)
	default_implementation()
	callback()
end

return source
