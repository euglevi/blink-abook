---@module "blink.cmp"

---@class blink-cmp-abook.Source : blink.cmp.Source
---@field config blink.cmp.SourceProviderConfig
local Source = {}

---@class blink-cmp-abook.Options
local defaults = {
    ---disable on certain filetypes
    ---@type string[]?
    disable_filetypes = {},
}

---@param id string
---@param config blink.cmp.SourceProviderConfig
---@return blink-cmp-abook.Source
function Source.new(id, config)
    local self = setmetatable({}, { __index = Source })

    self.id = id
    self.name = config.name
    self.module = config.module
    self.config = config
    self.config.opts = vim.tbl_deep_extend("force", defaults, self.config.opts or {})

    return self
end

function Source:enabled()
    return vim.bo.filetype == "mail"
        and not vim.tbl_contains(self.config.opts.disable_filetypes, vim.bo.filetype)
end

---@param context blink.cmp.Context
---@param resolve fun(response?: blink.cmp.CompletionResponse)
function Source:get_completions(context, resolve)
    local line = context.line
    local header_keywords = { "Bcc:", "Cc:", "From:", "Reply-To:", "To:" }
    local is_email_header = false

    for _, keyword in ipairs(header_keywords) do
        if line:match("^%s*" .. keyword) then
            is_email_header = true
            break
        end
    end

    if not is_email_header then
        resolve()
        return
    end

    local abook_output = vim.fn.system("abook --mutt-query .")
    if vim.v.shell_error ~= 0 then
        resolve()
        return
    end

    local cur_line, cur_col = unpack(context.cursor)

    local range = {
        ["start"] = {
            line = cur_line - 1,
            character = cur_col,
        },
        ["end"] = {
            line = cur_line - 1,
            character = cur_col,
        },
    }

    local lines = vim.split(abook_output, "\n")
    local items = {} ---@type blink.cmp.CompletionItem[]

    for _, line in ipairs(lines) do
        if line ~= "" then
            local parts = vim.split(line, "\t")
            local email = parts[1]
            if email then
                table.insert(items, {
                    label = email,
                    textEdit = {
                        range = range,
                        newText = email,
                    },
                    kind = vim.lsp.protocol.CompletionItemKind.Email,
                })
            end
        end
    end

    resolve({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return Source
