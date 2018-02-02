" Tests for autocommands

set belloff=all

function! s:cleanup_buffers() abort
  for bnr in range(1, bufnr('$'))
    if bufloaded(bnr) && bufnr('%') != bnr
      execute 'bd! ' . bnr
    endif
  endfor
endfunction

func Test_vim_did_enter()
  call assert_false(v:vim_did_enter)

  " This script will never reach the main loop, can't check if v:vim_did_enter
  " becomes one.
endfunc

if has('timers')
  func ExitInsertMode(id)
    call feedkeys("\<Esc>")
  endfunc

  func Test_cursorhold_insert()
    " Need to move the cursor.
    call feedkeys("ggG", "xt")

    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(100, 'ExitInsertMode')
    call feedkeys('a', 'x!')
    call assert_equal(1, g:triggered)
    au! CursorHoldI
    set updatetime&
  endfunc

  func Test_cursorhold_insert_ctrl_x()
    let g:triggered = 0
    au CursorHoldI * let g:triggered += 1
    set updatetime=20
    call timer_start(100, 'ExitInsertMode')
    " CursorHoldI does not trigger after CTRL-X
    call feedkeys("a\<C-X>", 'x!')
    call assert_equal(0, g:triggered)
    au! CursorHoldI
    set updatetime&
  endfunc
endif

function Test_bufunload()
  augroup test_bufunload_group
    autocmd!
    autocmd BufUnload * call add(s:li, "bufunload")
    autocmd BufDelete * call add(s:li, "bufdelete")
    autocmd BufWipeout * call add(s:li, "bufwipeout")
  augroup END

  let s:li=[]
  new
  setlocal bufhidden=
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=delete
  bunload
  call assert_equal(["bufunload", "bufdelete"], s:li)

  let s:li=[]
  new
  setlocal bufhidden=unload
  bwipeout
  call assert_equal(["bufunload", "bufdelete", "bufwipeout"], s:li)

  au! test_bufunload_group
  augroup! test_bufunload_group
endfunc

" SEGV occurs in older versions.  (At least 7.4.2005 or older)
function Test_autocmd_bufunload_with_tabnext()
  tabedit
  tabfirst

  augroup test_autocmd_bufunload_with_tabnext_group
    autocmd!
    autocmd BufUnload <buffer> tabnext
  augroup END

  quit
  call assert_equal(2, tabpagenr('$'))

  autocmd! test_autocmd_bufunload_with_tabnext_group
  augroup! test_autocmd_bufunload_with_tabnext_group
  tablast
  quit
endfunc

function Test_autocmd_bufwinleave_with_tabfirst()
  tabedit
  augroup sample
    autocmd!
    autocmd BufWinLeave <buffer> tabfirst
  augroup END
  call setline(1, ['a', 'b', 'c'])
  edit! a.txt
  tabclose
endfunc

" SEGV occurs in older versions.  (At least 7.4.2321 or older)
function Test_autocmd_bufunload_avoiding_SEGV_01()
  split aa.txt
  let lastbuf = bufnr('$')

  augroup test_autocmd_bufunload
    autocmd!
    exe 'autocmd BufUnload <buffer> ' . (lastbuf + 1) . 'bwipeout!'
  augroup END

  call assert_fails('edit bb.txt', 'E937:')

  autocmd! test_autocmd_bufunload
  augroup! test_autocmd_bufunload
  bwipe! aa.txt
  bwipe! bb.txt
endfunc

" SEGV occurs in older versions.  (At least 7.4.2321 or older)
function Test_autocmd_bufunload_avoiding_SEGV_02()
  setlocal buftype=nowrite
  let lastbuf = bufnr('$')

  augroup test_autocmd_bufunload
    autocmd!
    exe 'autocmd BufUnload <buffer> ' . (lastbuf + 1) . 'bwipeout!'
  augroup END

  normal! i1
  call assert_fails('edit a.txt', 'E517:')
  call feedkeys("\<CR>")

  autocmd! test_autocmd_bufunload
  augroup! test_autocmd_bufunload
  bwipe! a.txt
endfunc

func Test_win_tab_autocmd()
  let g:record = []

  augroup testing
    au WinNew * call add(g:record, 'WinNew')
    au WinEnter * call add(g:record, 'WinEnter') 
    au WinLeave * call add(g:record, 'WinLeave') 
    au TabNew * call add(g:record, 'TabNew')
    au TabClosed * call add(g:record, 'TabClosed')
    au TabEnter * call add(g:record, 'TabEnter')
    au TabLeave * call add(g:record, 'TabLeave')
  augroup END

  split
  tabnew
  close
  close

  call assert_equal([
	\ 'WinLeave', 'WinNew', 'WinEnter',
	\ 'WinLeave', 'TabLeave', 'WinNew', 'WinEnter', 'TabNew', 'TabEnter',
	\ 'WinLeave', 'TabLeave', 'TabClosed', 'WinEnter', 'TabEnter',
	\ 'WinLeave', 'WinEnter'
	\ ], g:record)

  let g:record = []
  tabnew somefile
  tabnext
  bwipe somefile

  call assert_equal([
	\ 'WinLeave', 'TabLeave', 'WinNew', 'WinEnter', 'TabNew', 'TabEnter',
	\ 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter',
	\ 'TabClosed'
	\ ], g:record)

  augroup testing
    au!
  augroup END
  unlet g:record
endfunc

func s:AddAnAutocmd()
  augroup vimBarTest
    au BufReadCmd * echo 'hello'
  augroup END
  call assert_equal(3, len(split(execute('au vimBarTest'), "\n")))
endfunc

func Test_early_bar()
  " test that a bar is recognized before the {event}
  call s:AddAnAutocmd()
  augroup vimBarTest | au! | augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  call s:AddAnAutocmd()
  augroup vimBarTest| au!| augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  " test that a bar is recognized after the {event}
  call s:AddAnAutocmd()
  augroup vimBarTest| au!BufReadCmd| augroup END
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))

  " test that a bar is recognized after the {group}
  call s:AddAnAutocmd()
  au! vimBarTest|echo 'hello'
  call assert_equal(1, len(split(execute('au vimBarTest'), "\n")))
endfunc

func RemoveGroup()
  autocmd! StartOK
  augroup! StartOK
endfunc

func Test_augroup_warning()
  augroup TheWarning
    au VimEnter * echo 'entering'
  augroup END
  call assert_true(match(execute('au VimEnter'), "TheWarning.*VimEnter") >= 0)
  redir => res
  augroup! TheWarning
  redir END
  call assert_true(match(res, "W19:") >= 0)
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)

  " check "Another" does not take the pace of the deleted entry
  augroup Another
  augroup END
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)
  augroup! Another

  " no warning for postpone aucmd delete
  augroup StartOK
    au VimEnter * call RemoveGroup()
  augroup END
  call assert_true(match(execute('au VimEnter'), "StartOK.*VimEnter") >= 0)
  redir => res
  doautocmd VimEnter
  redir END
  call assert_true(match(res, "W19:") < 0)
  au! VimEnter
endfunc

func Test_augroup_deleted()
  " This caused a crash before E936 was introduced
  augroup x
    call assert_fails('augroup! x', 'E936:')
    au VimEnter * echo
  augroup end
  augroup! x
  call assert_true(match(execute('au VimEnter'), "-Deleted-.*VimEnter") >= 0)
  au! VimEnter
endfunc

" Tests for autocommands on :close command.
" This used to be in test13.
func Test_three_windows()
  " Clean up buffers, because in some cases this function fails.
  call s:cleanup_buffers()

  " Write three files and open them, each in a window.
  " Then go to next window, with autocommand that deletes the previous one.
  " Do this twice, writing the file.
  e! Xtestje1
  call setline(1, 'testje1')
  w
  sp Xtestje2
  call setline(1, 'testje2')
  w
  sp Xtestje3
  call setline(1, 'testje3')
  w
  wincmd w
  au WinLeave Xtestje2 bwipe
  wincmd w
  call assert_equal('Xtestje1', expand('%'))

  au WinLeave Xtestje1 bwipe Xtestje3
  close
  call assert_equal('Xtestje1', expand('%'))

  " Test deleting the buffer on a Unload event.  If this goes wrong there
  " will be the ATTENTION prompt.
  e Xtestje1
  au!
  au! BufUnload Xtestje1 bwipe
  call assert_fails('e Xtestje3', 'E937:')
  call assert_equal('Xtestje3', expand('%'))

  e Xtestje2
  sp Xtestje1
  call assert_fails('e', 'E937:')
  call assert_equal('Xtestje2', expand('%'))

  " Test changing buffers in a BufWipeout autocommand.  If this goes wrong
  " there are ml_line errors and/or a Crash.
  au!
  only
  e Xanother
  e Xtestje1
  bwipe Xtestje2
  bwipe Xtestje3
  au BufWipeout Xtestje1 buf Xtestje1
  bwipe
  call assert_equal('Xanother', expand('%'))

  only

  helptags ALL
  help
  wincmd w
  1quit
  call assert_equal('Xanother', expand('%'))

  au!
  enew
  bwipe! Xtestje1
  call delete('Xtestje1')
  call delete('Xtestje2')
  call delete('Xtestje3')
endfunc

func Test_BufEnter()
  au! BufEnter
  au Bufenter * let val = val . '+'
  let g:val = ''
  split NewFile
  call assert_equal('+', g:val)
  bwipe!
  call assert_equal('++', g:val)

  " Also get BufEnter when editing a directory
  call mkdir('Xdir')
  split Xdir
  call assert_equal('+++', g:val)

  " On MS-Windows we can't edit the directory, make sure we wipe the right
  " buffer.
  bwipe! Xdir

  call delete('Xdir', 'd')
  au! BufEnter
endfunc

" Closing a window might cause an endless loop
" E814 for older Vims
function Test_autocmd_bufwipe_in_SessLoadPost()
  tabnew
  set noswapfile
  mksession!

  let content = ['set nocp noswapfile',
        \ 'let v:swapchoice="e"',
        \ 'augroup test_autocmd_sessionload',
        \ 'autocmd!',
        \ 'autocmd SessionLoadPost * 4bw!',
        \ 'augroup END',
	\ '',
	\ 'func WriteErrors()',
	\ '  call writefile([execute("messages")], "Xerrors")',
	\ 'endfunc',
	\ 'au VimLeave * call WriteErrors()',
        \ ]
  call writefile(content, 'Xvimrc')
  call system(v:progpath. ' --headless -i NONE -u Xvimrc --noplugins -S Session.vim -c cq')
  let errors = join(readfile('Xerrors'))
  call assert_match('E814', errors)

  set swapfile
  for file in ['Session.vim', 'Xvimrc', 'Xerrors']
    call delete(file)
  endfor
endfunc

" SEGV occurs in older versions.
function Test_autocmd_bufwipe_in_SessLoadPost2()
  tabnew
  set noswapfile
  mksession!

  let content = ['set nocp noswapfile',
      \ 'function! DeleteInactiveBufs()',
      \ '  tabfirst',
      \ '  let tabblist = []',
      \ '  for i in range(1, tabpagenr(''$''))',
      \ '    call extend(tabblist, tabpagebuflist(i))',
      \ '  endfor',
      \ '  for b in range(1, bufnr(''$''))',
      \ '    if bufexists(b) && buflisted(b) && (index(tabblist, b) == -1 || bufname(b) =~# ''^$'')',
      \ '      exec ''bwipeout '' . b',
      \ '    endif',
      \ '  endfor',
      \ '  echomsg "SessionLoadPost DONE"',
      \ 'endfunction',
      \ 'au SessionLoadPost * call DeleteInactiveBufs()',
      \ '',
      \ 'func WriteErrors()',
      \ '  call writefile([execute("messages")], "Xerrors")',
      \ 'endfunc',
      \ 'au VimLeave * call WriteErrors()',
      \ ]
  call writefile(content, 'Xvimrc')
  call system(v:progpath. ' --headless -i NONE -u Xvimrc --noplugins -S Session.vim -c cq')
  let errors = join(readfile('Xerrors'))
  " This probably only ever matches on unix.
  call assert_notmatch('Caught deadly signal SEGV', errors)
  call assert_match('SessionLoadPost DONE', errors)

  set swapfile
  for file in ['Session.vim', 'Xvimrc', 'Xerrors']
    call delete(file)
  endfor
endfunc

func Test_Cmdline()
  au! CmdlineEnter : let g:entered = expand('<afile>')
  au! CmdlineLeave : let g:left = expand('<afile>')
  let g:entered = 0
  let g:left = 0
  call feedkeys(":echo 'hello'\<CR>", 'xt')
  call assert_equal(':', g:entered)
  call assert_equal(':', g:left)
  au! CmdlineEnter
  au! CmdlineLeave

  au! CmdlineEnter / let g:entered = expand('<afile>')
  au! CmdlineLeave / let g:left = expand('<afile>')
  let g:entered = 0
  let g:left = 0
  call feedkeys("/hello<CR>", 'xt')
  call assert_equal('/', g:entered)
  call assert_equal('/', g:left)
  au! CmdlineEnter
  au! CmdlineLeave
endfunc

" Test for Bufleave autocommand that deletes the buffer we are about to edit.
func Test_BufleaveWithDelete()
  new | edit Xfile1

  augroup test_bufleavewithdelete
      autocmd!
      autocmd BufLeave Xfile1 bwipe Xfile2
  augroup END

  call assert_fails('edit Xfile2', 'E143:')
  call assert_equal('Xfile1', bufname('%'))

  autocmd! test_bufleavewithdelete BufLeave Xfile1
  augroup! test_bufleavewithdelete

  new
  bwipe! Xfile1
endfunc

" Test for Bufleave autocommand that deletes the buffer we are about to edit.
func Test_BufleaveWithDelete()
  new | edit Xfile1

  augroup test_bufleavewithdelete
      autocmd!
      autocmd BufLeave Xfile1 bwipe Xfile2
  augroup END

  call assert_fails('edit Xfile2', 'E143:')
  call assert_equal('Xfile1', bufname('%'))

  autocmd! test_bufleavewithdelete BufLeave Xfile1
  augroup! test_bufleavewithdelete

  new
  bwipe! Xfile1
endfunc

" Test for autocommand that changes the buffer list, when doing ":ball".
func Test_Acmd_BufAll()
  enew!
  %bwipe!
  call writefile(['Test file Xxx1'], 'Xxx1')
  call writefile(['Test file Xxx2'], 'Xxx2')
  call writefile(['Test file Xxx3'], 'Xxx3')

  " Add three files to the buffer list
  split Xxx1
  close
  split Xxx2
  close
  split Xxx3
  close

  " Wipe the buffer when the buffer is opened
  au BufReadPost Xxx2 bwipe

  call append(0, 'Test file Xxx4')
  ball

  call assert_equal(2, winnr('$'))
  call assert_equal('Xxx1', bufname(winbufnr(winnr('$'))))
  wincmd t

  au! BufReadPost
  %bwipe!
  call delete('Xxx1')
  call delete('Xxx2')
  call delete('Xxx3')
  enew! | only
endfunc

" Test for autocommand that changes current buffer on BufEnter event.
" Check if modelines are interpreted for the correct buffer.
func Test_Acmd_BufEnter()
  %bwipe!
  call writefile(['start of test file Xxx1',
	      \ "\<Tab>this is a test",
	      \ 'end of test file Xxx1'], 'Xxx1')
  call writefile(['start of test file Xxx2',
	      \ 'vim: set noai :',
	      \ "\<Tab>this is a test",
	      \ 'end of test file Xxx2'], 'Xxx2')

  au BufEnter Xxx2 brew
  set ai modeline modelines=3
  edit Xxx1
  " edit Xxx2, autocmd will do :brew
  edit Xxx2
  exe "normal G?this is a\<CR>"
  " Append text with autoindent to this file
  normal othis should be auto-indented
  call assert_equal("\<Tab>this should be auto-indented", getline('.'))
  call assert_equal(3, line('.'))
  " Remove autocmd and edit Xxx2 again
  au! BufEnter Xxx2
  buf! Xxx2
  exe "normal G?this is a\<CR>"
  " append text without autoindent to Xxx
  normal othis should be in column 1
  call assert_equal("this should be in column 1", getline('.'))
  call assert_equal(4, line('.'))

  %bwipe!
  call delete('Xxx1')
  call delete('Xxx2')
  set ai&vim modeline&vim modelines&vim
endfunc

" Test for issue #57
" do not move cursor on <c-o> when autoindent is set
func Test_ai_CTRL_O()
  enew!
  set ai
  let save_fo = &fo
  set fo+=r
  exe "normal o# abcdef\<Esc>2hi\<CR>\<C-O>d0\<Esc>"
  exe "normal o# abcdef\<Esc>2hi\<C-O>d0\<Esc>"
  call assert_equal(['# abc', 'def', 'def'], getline(2, 4))

  set ai&vim
  let &fo = save_fo
  enew!
endfunc

" Test for autocommand that deletes the current buffer on BufLeave event.
" Also test deleting the last buffer, should give a new, empty buffer.
func Test_BufLeave_Wipe()
  %bwipe!
  let content = ['start of test file Xxx',
	      \ 'this is a test',
	      \ 'end of test file Xxx']
  call writefile(content, 'Xxx1')
  call writefile(content, 'Xxx2')

  au BufLeave Xxx2 bwipe
  edit Xxx1
  split Xxx2
  " delete buffer Xxx2, we should be back to Xxx1
  bwipe
  call assert_equal('Xxx1', bufname('%'))
  call assert_equal(1, winnr('$'))

  " Create an alternate buffer
  %write! test.out
  call assert_equal('test.out', bufname('#'))
  " delete alternate buffer
  bwipe test.out
  call assert_equal('Xxx1', bufname('%'))
  call assert_equal('', bufname('#'))

  au BufLeave Xxx1 bwipe
  " delete current buffer, get an empty one
  bwipe!
  call assert_equal(1, line('$'))
  call assert_equal('', bufname('%'))
  call assert_equal(1, len(getbufinfo()))

  call delete('Xxx1')
  call delete('Xxx2')
  %bwipe
  au! BufLeave
endfunc
