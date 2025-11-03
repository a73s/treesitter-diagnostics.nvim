local ts_diag = {}

local defaults = {

    enabled = true,
    -- of the same format as "*.cpp" for c++ files or "*.h" for header files, or "*py" for python files
    patterns = {},
}

ts_diag.setup = function(opts)

    local settings = vim.tbl_extend('force', defaults, opts or {})

    if settings.enabled then
        -- credit to for this code goes to u/robertgrows on reddit
        --- language-independent query for syntax errors and missing elements
        local error_query = vim.treesitter.query.parse('query', '[(ERROR)(MISSING)] @a')
        local namespace = vim.api.nvim_create_namespace('treesitter.diagnostics.nvim')

        --- @param args vim.api.keyset.create_autocmd.callback_args
        local function diagnose(args)
            if not vim.diagnostic.is_enabled({bufnr = args.buf}) then
                return
            end

            local success, toReturn = pcall(
                function ()
                    -- don't diagnose strange stuff
                    if vim.bo[args.buf].buftype ~= '' then
                        return true
                    else
                        return false
                    end
                end
            )

            -- catch the error that happens sometimes when the buffer does not exist
            if not success or toReturn then
                return
            end

            local diagnostics = {}
            local parser = vim.treesitter.get_parser(args.buf, nil, { error = false })
            if parser then
                parser:parse(false, function(_, trees)
                    if not trees then
                        return
                    end
                    parser:for_each_tree(function(tree, ltree)
                        -- only process trees containing errors
                        if tree:root():has_error() then
                            for _, node in error_query:iter_captures(tree:root(), args.buf) do
                                local lnum, col, end_lnum, end_col = node:range()

                                -- collapse nested syntax errors that occur at the exact same position
                                local parent = node:parent()
                                if parent and parent:type() == 'ERROR' and parent:range() == node:range() then
                                    goto continue
                                end

                                -- clamp large syntax error ranges to just the line to reduce noise
                                if end_lnum > lnum then
                                    end_lnum = lnum + 1
                                    end_col = 0
                                end

                                --- @type vim.Diagnostic
                                local diagnostic = {
                                    source = 'treesitter',
                                    lnum = lnum,
                                    end_lnum = end_lnum,
                                    col = col,
                                    end_col = end_col,
                                    message = '',
                                    code = string.format('%s-syntax', ltree:lang()),
                                    bufnr = args.buf,
                                    namespace = namespace,
                                    severity = vim.diagnostic.severity.ERROR
                                }
                                if node:missing() then
                                    diagnostic.message = string.format('missing `%s`', node:type())
                                else
                                    diagnostic.message = 'error'
                                end

                                -- add context to the error using sibling and parent nodes
                                local previous = node:prev_sibling()
                                if previous and previous:type() ~= 'ERROR' then
                                    local previous_type = previous:named() and previous:type() or string.format('`%s`', previous:type())
                                    diagnostic.message = diagnostic.message .. ' after ' .. previous_type
                                end

                                if parent and parent:type() ~= 'ERROR' and (previous == nil or previous:type() ~= parent:type()) then
                                    diagnostic.message = diagnostic.message .. ' in ' .. parent:type()
                                end

                                table.insert(diagnostics, diagnostic)
                                ::continue::
                            end
                        end
                    end)
                end)
                vim.diagnostic.set(namespace, args.buf, diagnostics)
            end
        end


        local autocmd_group = vim.api.nvim_create_augroup('treesitter-diagnostics.nvim', { clear = true })

        vim.api.nvim_create_autocmd({ 'FileType', 'TextChanged', 'InsertLeave' }, {
            pattern = settings.patterns,
            desc = 'treesitter diagnostics',
            group = autocmd_group,
            callback = vim.schedule_wrap(diagnose),
        })
    end

end

return ts_diag
