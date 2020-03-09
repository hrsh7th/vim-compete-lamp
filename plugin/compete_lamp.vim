if exists('g:loaded_compete_lamp')
  finish
endif
let g:loaded_compete_lamp = v:true

call compete#source#lamp#register()

