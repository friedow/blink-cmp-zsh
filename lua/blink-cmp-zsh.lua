--- @module 'blink.cmp'

--- @class blink.cmp.Source
local source = {}

--- Create a new blink.cmp source for zsh completions.
---
--- @param opts blink.cmp.ContextOpts
function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts
	return self
end

--- Whether to enable the zsh source.
---
--- @return boolean
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

--- Get the completions based on the current command.
---
--- @param context blink.cmp.Context
--- @param callback fun(response?: blink.cmp.CompletionResponse)
--- @return nil
function source:get_completions(context, callback)
	vim.print(context)
	if context.terminal == nil or context.terminal.command == nil then
		callback({
			is_incomplete_forward = true,
			is_incomplete_backward = true,
		})
		return
	end

	local running_command = vim.system(
		{ "zsh", script_path() .. "/capture.zsh", context.terminal.command },
		nil,
		function(result)
			if result.code ~= 0 then
				callback({
					is_incomplete_forward = true,
					is_incomplete_backward = true,
				})
				return
			end

			local lines = vim.split(result.stdout, "\r\n", { plain = true })

			--- @type lsp.CompletionItem[]
			local items = {}

			vim.iter(lines):each(function(line)
				local completion_parts = vim.split(line, " -- ", { plain = true })
				local command = completion_parts[1]
				local description = completion_parts[2]
				table.insert(items, {
					label = command,
					description = description,
					kind = require("blink.cmp.types").CompletionItemKind.Text,
					insertText = command,
				})
			end)

			callback({
				is_incomplete_forward = true,
				is_incomplete_backward = true,
				items = items,
			})
		end
	)

	return function()
		running_command.kill(running_command, 9)
	end
end

return source
