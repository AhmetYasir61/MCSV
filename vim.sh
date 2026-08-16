#!/bin/bash
# just vim setup. This is for reference. This should already be a part of vps.sh

cd /root
touch .vimrc
echo "let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25
augroup ProjectDrawer
  autocmd!
  autocmd VimEnter * :Vexplore
augroup END
syntax on
colorscheme industry
set tabstop=4 shiftwidth=4 expandtab" > .vimrc
cat .vimrc
