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

function source:get_completions(context, callback)
	-- ctx (context) contains the current keyword, cursor position, bufnr, etc.

  vim.print(vim.inspect(context))

	if string.len(context.line) == 0 then
		resolve()
		return
	end

	vim.system(
    -- TODO: fix absolute path
    -- TODO: strip the shell prompt from context.line before using it
		{ "zsh", "<PATH TO PROJECT>/blink-cmp-zsh/lua/capture.zsh", context.line },
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
