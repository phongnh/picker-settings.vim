if globpath(&rtp, 'plugin/picker.vim') == ''
    echohl WarningMsg | echomsg 'picker.vim is not found.' | echohl none
    finish
endif

if get(g:, 'loaded_picker_settings_vim', 0)
    finish
endif

let g:picker_height = 15

let g:picker_file_root_markers = [
            \ 'Gemfile',
            \ 'rebar.config',
            \ 'mix.exs',
            \ 'Cargo.toml',
            \ 'shard.yml',
            \ 'go.mod'
            \ ]

let g:picker_root_markers = ['.git', '.hg', '.svn', '.bzr', '_darcs'] + g:picker_file_root_markers

let s:picker_ignored_root_dirs = [
            \ '/',
            \ '/root',
            \ '/Users',
            \ '/home',
            \ '/usr',
            \ '/usr/local',
            \ '/opt',
            \ '/etc',
            \ '/var',
            \ expand('~'),
            \ ]

function! s:FindProjectDir(starting_dir) abort
    if empty(a:starting_dir)
        return ''
    endif

    let l:root_dir = ''

    for l:root_marker in g:picker_root_markers
        if index(g:picker_file_root_markers, l:root_marker) > -1
            let l:root_dir = findfile(l:root_marker, a:starting_dir . ';')
        else
            let l:root_dir = finddir(l:root_marker, a:starting_dir . ';')
        endif
        let l:root_dir = substitute(l:root_dir, l:root_marker . '$', '', '')

        if strlen(l:root_dir)
            let l:root_dir = fnamemodify(l:root_dir, ':p:h')
            break
        endif
    endfor

    if empty(l:root_dir) || index(s:picker_ignored_root_dirs, l:root_dir) > -1
        if index(s:picker_ignored_root_dirs, getcwd()) > -1
            let l:root_dir = a:starting_dir
        elseif stridx(a:starting_dir, getcwd()) == 0
            let l:root_dir = getcwd()
        else
            let l:root_dir = a:starting_dir
        endif
    endif

    return fnamemodify(l:root_dir, ':p:~')
endfunction

command! PickerRoot execute 'PickerEdit' s:FindProjectDir(expand('%:p:h'))

let s:picker_available_commands = filter(['rg', 'fd'], 'executable(v:val)')

if empty(s:picker_available_commands)
    command! -nargs=? -complete=dir PickerAll :PickerEdit <args>
    finish
endif

let g:picker_find_tool    = get(g:, 'picker_find_tool', 'rg')
let g:picker_follow_links = get(g:, 'picker_follow_links', 0)
let s:picker_follow_links = g:picker_follow_links
let g:picker_no_ignores   = get(g:, 'picker_no_ignores', 0)
let s:picker_no_ignores   = g:picker_no_ignores

let s:picker_find_commands = {
            \ 'rg': 'rg --files --color never --no-ignore-vcs --ignore-dot --ignore-parent --hidden',
            \ 'fd': 'fd --type file --color never --no-ignore-vcs --hidden',
            \ }

let s:picker_find_all_commands = {
            \ 'rg': 'rg --files --color never --no-ignore --hidden',
            \ 'fd': 'fd --type file --color never --no-ignore --hidden',
            \ }

function! s:BuildFindCommand() abort
    let l:cmd = s:picker_find_commands[s:picker_current_command]
    if s:picker_no_ignores
        let l:cmd = s:picker_find_all_commands[s:picker_current_command]
    endif
    if s:picker_follow_links
        let l:cmd .= ' --follow'
    endif
    return l:cmd
endfunction

function! s:DetectPickerCurrentCommand() abort
    let idx = index(s:picker_available_commands, g:picker_find_tool)
    let s:picker_current_command = get(s:picker_available_commands, idx > -1 ? idx : 0)
endfunction

function! s:BuildPickerCustomCommand() abort
    let l:cmd = split(s:BuildFindCommand())
    let g:picker_custom_find_executable = l:cmd[0]
    let g:picker_custom_find_flags = join(l:cmd[1:-1], ' ')
endfunction

function! s:PrintPickerCurrentCommandInfo() abort
    echo 'Picker is using command `' . g:picker_custom_find_executable . '`!'
endfunction

command! PrintPickerCurrentCommandInfo call <SID>PrintPickerCurrentCommandInfo()

function! s:ChangePickerCustomCommand(bang, command) abort
    " Reset to default command
    if a:bang
        call s:DetectPickerCurrentCommand()
    elseif strlen(a:command)
        if index(s:picker_available_commands, a:command) == -1
            return
        endif
        let s:picker_current_command = a:command
    else
        let idx = index(s:picker_available_commands, s:picker_current_command)
        let s:picker_current_command = get(s:picker_available_commands, idx + 1, s:picker_available_commands[0])
    endif
    call s:BuildPickerCustomCommand()
    call s:PrintPickerCurrentCommandInfo()
endfunction

function! s:ListPickerAvailableCommands(...) abort
    return s:picker_available_commands
endfunction

command! -nargs=? -bang -complete=customlist,<SID>ListPickerAvailableCommands ChangePickerCustomCommand call <SID>ChangePickerCustomCommand(<bang>0, <q-args>)

function! s:TogglePickerFollowLinks() abort
    if s:picker_follow_links == 0
        let s:picker_follow_links = 1
        echo 'Picker follows symlinks!'
    else
        let s:picker_follow_links = 0
        echo 'Picker does not follow symlinks!'
    endif
    call s:BuildPickerCustomCommand()
endfunction

command! TogglePickerFollowLinks call <SID>TogglePickerFollowLinks()

function! s:TogglePickerNoIgnores() abort
    if s:picker_no_ignores == 0
        let s:picker_no_ignores = 1
        echo 'Picker does not respect ignores!'
    else
        let s:picker_no_ignores = 0
        echo 'Picker respects ignores!'
    endif
    call s:BuildPickerCustomCommand()
endfunction

command! TogglePickerNoIgnores call <SID>TogglePickerNoIgnores()


function! s:PickerAll(dir) abort
    let current = s:picker_no_ignores
    try
        let s:picker_no_ignores = 1
        call s:BuildPickerCustomCommand()
        execute 'PickerEdit' a:dir
    finally
        let s:picker_no_ignores = current
        call s:BuildPickerCustomCommand()
    endtry
endfunction

command! -nargs=? -complete=dir PickerAll call <SID>PickerAll(<q-args>)

call s:DetectPickerCurrentCommand()
call s:BuildPickerCustomCommand()

let g:loaded_picker_settings_vim = 1
