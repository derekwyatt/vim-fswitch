" ============================================================================
" File:        fswitch.vim
"
" Description: Vim global plugin that provides decent companion source file
"              switching
"
" Maintainer:  Derek Wyatt <derek at myfirstnamemylastname dot org>
"
" Last Change: March 23rd 2009
"
" License:     This program is free software. It comes without any warranty,
"              to the extent permitted by applicable law. You can redistribute
"              it and/or modify it under the terms of the Do What The Fuck You
"              Want To Public License, Version 2, as published by Sam Hocevar.
"              See http://sam.zoy.org/wtfpl/COPYING for more details.
" ============================================================================

if exists("g:disable_fswitch")
    finish
endif

if v:version < 700
  echoerr "FSwitch requires Vim 7.0 or higher."
  finish
endif

" Version
let s:fswitch_version = '0.9.5'

" Get the path separator right
let s:os_slash = &ssl == 0 && (has("win16") || has("win32") || has("win64")) ? '\' : '/'

" Default locations - appended to buffer locations unless otherwise specified
let s:fswitch_global_locs = '.' . s:os_slash

"
" s:SetVariables
"
" There are two variables that need to be set in the buffer in order for things
" to work correctly.  Because we're using an autocmd to set things up we need to
" be sure that the user hasn't already set them for us explicitly so we have
" this function just to check and make sure.  If the user's autocmd runs after
" ours then they will override the value anyway.
"
function! s:SetVariables(dst, locs)
    if !exists("b:fswitchdst")
        let b:fswitchdst = a:dst
    endif
    if !exists("b:fswitchlocs")
        let b:fswitchlocs = a:locs
    endif
endfunction

"
" s:FSGetLocations
"
" Return the list of possible locations
"
function! s:FSGetLocations()
    let locations = []
    if exists("b:fswitchlocs")
        let locations = split(b:fswitchlocs, ',')
    endif
    if !exists("b:fsdisablegloc") || b:fsdisablegloc == 0
        let locations += split(s:fswitch_global_locs, ',')
    endif

    return locations
endfunction

"
" s:FSGetExtensions
"
" Return the list of destination extensions
"
function! s:FSGetExtensions()
    return split(b:fswitchdst, ',')
endfunction

"
" s:FSGetFilenameMutations
"
" Return the list of possible filename mutations
"
function! s:FSGetFilenameMutations()
    if !exists("b:fswitchfnames")
        " For backward-compatibility out default mutation is an identity.
        return ['/^//']
    else
        return split(b:fswitchfnames, ',')
    endif
endfunction

"
" s:FSGetMustMatch
"
" Return a boolean on whether or not the regex must match
"
function! s:FSGetMustMatch()
    let mustmatch = 1
    if exists("b:fsneednomatch") && b:fsneednomatch != 0
        let mustmatch = 0
    endif

    return mustmatch
endfunction

"
" s:FSGetFullPathToDirectory
"
" Given the filename, return the fully qualified directory portion
"
function! s:FSGetFullPathToDirectory(filename)
    return expand(a:filename . ':p:h')
endfunction

"
" s:FSGetFileExtension
"
" Given the filename, returns the extension
"
function! s:FSGetFileExtension(filename)
    return expand(a:filename . ':e')
endfunction

"
" s:FSGetFileNameWithoutExtension
"
" Given the filename, returns just the file name without the path or extension
"
function! s:FSGetFileNameWithoutExtension(filename)
    return expand(a:filename . ':t:r')
endfunction

"
" s:FSMutateFilename
"
" Takes a filename and a filename mutation directive and applies the mutation
" to it.
function! s:FSMutateFilename(filename, directive)
    let separator = strpart(a:directive, 0, 1)
    let dirparts = split(strpart(a:directive, 1), separator)
    if len(dirparts) < 2 || len(dirparts) > 3
        throw 'Bad mutation directive "' . a:directive . '".'
    else
        let flags = ''
        if len(dirparts) == 3
            let flags = dirparts[2]
        endif
        return substitute(a:filename, dirparts[0], dirparts[1], flags)
    endif
endfunction

"
" s:FSGetAlternateFilename
"
" Takes the path, name and extension of the file in the current buffer and
" applies the location to it.  If the location is a regular expression pattern
" then it will split that up and apply it accordingly.  If the location pattern
" is actually an explicit relative path or an implicit one (default) then it
" will simply apply that to the file directly.
"
function! s:FSGetAlternateFilename(filepath, filename, newextension, location, mustmatch)
    let parts = split(a:location, ':')
    let cmd = 'rel'
    let directive = parts[0]
    if len(parts) == 2
        let cmd = parts[0]
        let directive = parts[1]
    endif
    if cmd == 'reg' || cmd == 'ifrel' || cmd == 'ifabs'
        if strlen(directive) < 3
            throw 'Bad directive "' . a:location . '".'
        else
            let separator = strpart(directive, 0, 1)
            let dirparts = split(strpart(directive, 1), separator)
            if len(dirparts) < 2 || len(dirparts) > 3
                throw 'Bad directive "' . a:location . '".'
            else
                let part1 = dirparts[0]
                let part2 = dirparts[1]
                let flags = ''
                if len(dirparts) == 3
                    let flags = dirparts[2]
                endif
                if cmd == 'reg'
                    if a:mustmatch == 1 && match(a:filepath, part1) == -1
                        let path = ""
                    else
                        let path = substitute(a:filepath, part1, part2, flags) . s:os_slash .
                                    \ a:filename . '.' . a:newextension
                    endif
                elseif cmd == 'ifrel'
                    if match(a:filepath, part1) == -1
                        let path = ""
                    else
                        let path = a:filepath . s:os_slash . part2 . 
                                     \ s:os_slash . a:filename . '.' . a:newextension
                    endif
                elseif cmd == 'ifabs'
                    if match(a:filepath, part1) == -1
                        let path = ""
                    else
                        let path = part2 . s:os_slash . a:filename . '.' . a:newextension
                    endif
                endif
            endif
        endif
    elseif cmd == 'rel'
        let path = a:filepath . s:os_slash . directive . s:os_slash . a:filename . '.' . a:newextension
    elseif cmd == 'abs'
        let path = directive . s:os_slash . a:filename . '.' . a:newextension
    endif

    return simplify(path)
endfunction

"
" s:FSReturnCompanionFilename
"
" This function will return a path that is the best candidate for the companion
" file to switch to.  If mustBeReadable == 1 when then the companion file will
" only be returned if it is readable on the filesystem, otherwise it will be
" returned so long as it is non-empty.
"
function! s:FSReturnCompanionFilename(filename, mustBeReadable)
    let fullpath = s:FSGetFullPathToDirectory(a:filename)
    let ext = s:FSGetFileExtension(a:filename)
    let justfile = s:FSGetFileNameWithoutExtension(a:filename)
    let extensions = s:FSGetExtensions()
    let filenameMutations = s:FSGetFilenameMutations()
    let locations = s:FSGetLocations()
    let mustmatch = s:FSGetMustMatch()
    let newpath = ''
    for currentExt in extensions
        for loc in locations
            for filenameMutation in filenameMutations
                let mutatedFilename = s:FSMutateFilename(justfile, filenameMutation)
                let newpath = s:FSGetAlternateFilename(fullpath, mutatedFilename, currentExt, loc, mustmatch)
                if a:mustBeReadable == 0 && newpath != ''
                    return newpath
                elseif a:mustBeReadable == 1
                    let newpath = glob(newpath)
                    if filereadable(newpath)
                        return newpath
                    endif
                endif
            endfor
        endfor
    endfor

    return newpath
endfunction

"
" FSReturnReadableCompanionFilename
"
" This function will return a path that is the best candidate for the companion
" file to switch to, so long as that file actually exists on the filesystem and
" is readable.
" 
function! FSReturnReadableCompanionFilename(filename)
    return s:FSReturnCompanionFilename(a:filename, 1)
endfunction

"
" FSReturnCompanionFilenameString
"
" This function will return a path that is the best candidate for the companion
" file to switch to.  The file does not need to actually exist on the
" filesystem in order to qualify as a proper companion.
"
function! FSReturnCompanionFilenameString(filename)
    return s:FSReturnCompanionFilename(a:filename, 0)
endfunction

"
" FSwitch
"
" This is the only externally accessible function and is what we use to switch
" to the alternate file.
"
function! FSwitch(filename, precmd)
    if !exists("b:fswitchdst") || strlen(b:fswitchdst) == 0
        throw 'b:fswitchdst not set - read :help fswitch'
    endif
    if (!exists("b:fswitchlocs")   || strlen(b:fswitchlocs) == 0) &&
     \ (!exists("b:fsdisablegloc") || b:fsdisablegloc == 0)
        throw "There are no locations defined (see :h fswitchlocs and :h fsdisablegloc)"
    endif
    let newpath = FSReturnReadableCompanionFilename(a:filename)
    let openfile = 1
    if !filereadable(newpath)
        if exists("b:fsnonewfiles") || exists("g:fsnonewfiles")
            let openfile = 0
        else
            let newpath = FSReturnCompanionFilenameString(a:filename)
        endif
    endif
    if &switchbuf =~ "^use"
        let i = 1
        let bufnum = winbufnr(i)
        while bufnum != -1
            let filename = fnamemodify(bufname(bufnum), ':p')
            if filename == newpath
                execute ":sbuffer " .  filename
                return
            endif
            let i += 1
            let bufnum = winbufnr(i)
        endwhile
    endif
    if openfile == 1
        if newpath != ''
            if strlen(a:precmd) != 0
                execute a:precmd
            endif
            if bufexists(newpath)
                execute 'buffer ' . fnameescape(newpath)
            else
                execute 'edit ' . fnameescape(newpath)
            endif
        else
            echoerr "Alternate has evaluated to nothing.  See :h fswitch-empty for more info."
        endif
    else
        echoerr "No alternate file found.  'fsnonewfiles' is set which denies creation."
    endif
endfunction

"
" The autocmds we set up to set up the buffer variables for us.
"
augroup fswitch_au_group
    au!
    au BufEnter *.c    call s:SetVariables('h',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cc   call s:SetVariables('hh',      'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cpp  call s:SetVariables('hpp,h',   'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.cxx  call s:SetVariables('hxx',     'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.C    call s:SetVariables('H',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.m    call s:SetVariables('h',       'reg:/src/include/,reg:|src|include/**|,ifrel:|/src/|../include|')
    au BufEnter *.h    call s:SetVariables('c,cpp,m', 'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hh   call s:SetVariables('cc',      'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hpp  call s:SetVariables('cpp',     'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.hxx  call s:SetVariables('cxx',     'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
    au BufEnter *.H    call s:SetVariables('C',       'reg:/include/src/,reg:/include.*/src/,ifrel:|/include/|../src|')
augroup END

"
" The mappings used to do the good work
"
com! FSHere       :call FSwitch('%', '')
com! FSRight      :call FSwitch('%', 'wincmd l')
com! FSSplitRight :call FSwitch('%', 'let curspr=&spr | set nospr | vsplit | wincmd l | if curspr | set spr | endif')
com! FSLeft       :call FSwitch('%', 'wincmd h')
com! FSSplitLeft  :call FSwitch('%', 'let curspr=&spr | set nospr | vsplit | if curspr | set spr | endif')
com! FSAbove      :call FSwitch('%', 'wincmd k')
com! FSSplitAbove :call FSwitch('%', 'let cursb=&sb | set nosb | split | if cursb | set sb | endif')
com! FSBelow      :call FSwitch('%', 'wincmd j')
com! FSSplitBelow :call FSwitch('%', 'let cursb=&sb | set nosb | split | wincmd j | if cursb | set sb | endif')

