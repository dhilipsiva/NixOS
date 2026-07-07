" Declarations\
" let g:syntastic_disabled_filetypes=['python']
" let g:racer_cmd = "~/.cargo/bin/racer"
let g:NERDCompactSexyComs = 1 " Use compact syntax for prettified multi-line comments
let g:NERDSpaceDelims = 1 " Add spaces after comment delimiters by default
let g:NERDTreeIgnore = ['\.pyc$']
let g:NERDTrimTrailingWhitespace = 1 " Enable trimming of trailing whitespace when uncommenting
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:airline_powerline_fonts = 1 " Vim devicons for powerline
let g:airline_theme='onedark'
let g:deoplete#enable_at_startup = 1 " Start deoplete at startup
let g:deoplete#sources#jedi#enable_typeinfo = 0
let g:flake8_cmd="pflake8"
let g:go_def_mode='gopls'
let g:go_info_mode='gopls'
let g:indentLine_char_list = ['|', '¦', '┆', '┊']
let g:indentLine_setColors = 0
let g:jsx_ext_required = 0
let g:mkdp_path_to_chrome = "chromium" " Open Markdown preview in chromium
let g:pymode_lint_checkers = ['pyflakes', 'pep8', 'mccabe']
let g:pymode_rope = 0
let g:pymode_rope_lookup_project = 0
let g:pymode_virtualenv = 1
let g:ropevim_vim_completion=0
let g:rustfmt_autosave = 1
let g:sneak#label = 1 " Show labels while using sneak
let g:syntastic_mode_map = {'mode': 'passive', 'active_filetypes': ['javascript'], 'passive_filetypes': [] }
let g:vim_json_syntax_conceal = 0


syntax on
nmap <F8> :TagbarToggle<CR>
cabbr <expr> %% expand('%:p:h')

set hidden
set tabstop=4
set shiftwidth=4
set expandtab
set nowrap

set background=dark
set colorcolumn=89
set encoding=utf8
set ignorecase smartcase
set number
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*.pyc,.git/*,*/node_modules/*,*/bower_components/*

autocmd BufNewFile,BufRead *.cap   set syntax=ruby
autocmd BufNewFile,BufRead *.json,Pipfile.lock set syntax=javascript
autocmd BufNewFile,BufRead *.dockerfile set syntax=dockerfile
autocmd BufNewFile,BufRead Pipfile set filetype=toml
autocmd BufWritePost *.go GoBuild
autocmd BufWritePre * :%s/\s\+$//e "Trim the line endings
autocmd BufWritePre *.js,*.jsx,*.ts,*.tsx Neoformat prettier
autocmd BufWritePost *.py call Flake8()
autocmd BufWritePre *.py execute ':Black'
autocmd BufWritePre *.rs execute ':RustFmt'

au BufNewFile,BufReadPost *.coffee,*.rb,*.yml,*.yaml,*.js,*.jsx,*.jade,*.pug,*.scss,*.scm,*.toml,*.json setl tabstop=2 shiftwidth=2 expandtab
au BufNewFile,BufReadPost *.emblem,*.haml,*.py,*.coffee,*.jade set foldmethod=indent
au BufNewFile,BufReadPost *.html,*.c setl tabstop=4 shiftwidth=4 expandtab

augroup Racer
    autocmd!
    autocmd FileType rust nmap <buffer> gd         <Plug>(rust-def)
    autocmd FileType rust nmap <buffer> gs         <Plug>(rust-def-split)
    autocmd FileType rust nmap <buffer> gx         <Plug>(rust-def-vertical)
    autocmd FileType rust nmap <buffer> gt         <Plug>(rust-def-tab)
    autocmd FileType rust nmap <buffer> <leader>gd <Plug>(rust-doc)
    autocmd FileType rust nmap <buffer> <leader>gD <Plug>(rust-doc-tab)
augroup END

call plug#begin('~/.vim/plugged')
" Make sure you use single quotes



" Trigger configuration (Optional)
" Plug 'wakatime/vim-wakatime'
Plug 'LnL7/vim-nix'
Plug 'Quramy/tsuquyomi'
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'SirVer/ultisnips'
Plug 'Valloric/MatchTagAlways'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'Yggdroot/indentLine'
Plug 'airblade/vim-gitgutter'
Plug 'alvan/vim-closetag'
Plug 'artur-shaik/vim-javacomplete2'
Plug 'cespare/vim-toml'
Plug 'deoplete-plugins/deoplete-dictionary'
Plug 'deoplete-plugins/deoplete-jedi'
Plug 'deoplete-plugins/deoplete-tag'
Plug 'digitaltoad/vim-pug'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'editorconfig/editorconfig-vim'
Plug 'elixir-editors/vim-elixir'
Plug 'elzr/vim-json'
Plug 'epilande/vim-react-snippets'
Plug 'fisadev/vim-isort'
Plug 'github/copilot.vim'
Plug 'hashivim/vim-terraform'
Plug 'honza/vim-snippets'
Plug 'jiangmiao/auto-pairs'
Plug 'jparise/vim-graphql'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'junegunn/goyo.vim'
Plug 'leafgarland/typescript-vim'
Plug 'majutsushi/tagbar'
Plug 'mg979/vim-visual-multi'
Plug 'mlaursen/vim-react-snippets'
Plug 'mxw/vim-jsx'
Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins'}
Plug 'nvie/vim-flake8'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'osohq/polar.vim'
Plug 'othree/html5.vim'
Plug 'pangloss/vim-javascript'
Plug 'pest-parser/pest.vim'
Plug 'psf/black'
Plug 'racer-rust/vim-racer'
Plug 'rust-lang/rust.vim'
Plug 'ryanoasis/vim-devicons'
Plug 'sbdchd/neoformat'
Plug 'scrooloose/nerdcommenter'
Plug 'scrooloose/nerdtree'
Plug 'scrooloose/syntastic'
Plug 'slashmili/alchemist.vim'
Plug 'solarnz/thrift.vim'
Plug 'suzuki11109/robot.vim'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'wellle/targets.vim'
" let g:UltiSnipsExpandTrigger="<C-l>"
"
" Initialize plugin system
call plug#end()
call deoplete#custom#option('auto_complete_delay', 100)


" Post Plugin stuff
colorscheme dracula
