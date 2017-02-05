function! Bind(f, ...)
  let args = deepcopy(a:000)
  return function(a:f, args)
endfunction

function! ResetResize()
  if exists('g:embiggen')
    unlet g:embiggen
  endif
endfunction

function! WinEqualSize()
  call ResetResize()
  wincmd =
endfunction

function! Reversed(list)
    let new_list = deepcopy(a:list)
    call reverse(new_list)
    return new_list
endfunction

function! Mapped(fn, l)
    let new_list = deepcopy(a:l)
    call map(new_list, {k,v->a:fn(v)})
    return new_list
endfunction

function! Add(a,b)
  return a:a + a:b
endfunction

function! Reduced(func, acc, list)
  let acc  = a:acc
  for item in a:list
    let acc = a:func(acc, item)
  endfor
  return acc
endfunction

function! Sum(list)
  return Reduced(function('Add'), 0, a:list)
endfunction

function! WindowsInDirection(dir)
  let win    = win_getid()
  let wincount = 0
  let windows_in_dir = []

  let current_win = -1
  let last_win = win
  while current_win != last_win
    let last_win = current_win
    let current_win = win_getid()
    if current_win != win && current_win != last_win
      let windows_in_dir = windows_in_dir + [current_win]
    endif
    let wincount += 1
    if a:dir ==? 'left'
      wincmd h
    elseif a:dir ==? 'right'
      wincmd l
    elseif a:dir ==? 'up'
      wincmd k
    else
      wincmd j
    endif
  endwhile
  call win_gotoid(win)
  return windows_in_dir
endfunction

function! ResizeWindow(window, dir, size)
  call win_gotoid(a:window)
  if a:dir ==? "x"
    exe "vertical resize " . float2nr(round(a:size))
  else
    exe "resize " . float2nr(round(a:size))
  endif
endfunction

function! Min(float_list)
  let smallest = a:float_list[0]
  for f in a:float_list
    let smallest = f < smallest ? f : smallest
  endfor
  return smallest
endfunction

function! Max(float_list)
  let biggest = a:float_list[0]
  for f in a:float_list
    let biggest = f > biggest ? f : biggest
  endfor
  return biggest
endfunction

function! AnyDifferent(a, b)
  for i in items(a:a)
    if !has_key(a:b, i[0]) || a:b[i[0]].width != i[1].width || a:b[i[0]].height != i[1].height
      return 1
    end
  endfor
  return 0
endfunction

function! GetSize()
  let size={}
  for w in getwininfo()
    let size[w['winid']] = {'width': w['width'], 'height': w['height']}
  endfor
  return size
endfunction

function! DictFrom(func, keys)
  let output = {}
  for k in a:keys
    let output[k] = a:func(k)
  endfor
  return output
endfunction

function! MappedValues(func, input)
  let output={}
  for [k,v] in items(a:input)
    let output[k] = a:func(v)
  endfor
  return output
endfunction

function! Resized(width_frac, height_frac, window_info)
  return {
  \  'window': a:window_info['window'],
  \  'size':   {
  \    'width':  (a:window_info['size']['width']  * a:width_frac),
  \    'height': (a:window_info['size']['height'] * a:height_frac)
  \  }
  \}
endfunction

function! Resize(plus)
  let win          = win_getid()
  let initial_size = GetSize()

  if !exists('g:embiggen') || g:embiggen.window != win || (has_key(g:embiggen, 'last_size') && AnyDifferent(initial_size, g:embiggen.last_size))
    let g:embiggen = {
    \  'window':    win,
    \  'size':      initial_size,
    \  'zoom':      0,
    \  'last_size': initial_size
    \}
  endif
  let zoom = g:embiggen.zoom + a:plus
  let ratio = pow((4.0/3.0), zoom)

  let wins_size = MappedValues({v->Mapped({w->{'window': w, 'size': g:embiggen.size[w]}},v)}, DictFrom(function('WindowsInDirection'), ['left','right','up','down']))
  let g:wins_size = wins_size


  let original_width  = g:embiggen.size[win].width
  let original_height = g:embiggen.size[win].height
  let total_width  = Sum(Mapped({s->s.size.width},  wins_size.left + wins_size.right)) + original_width
  let total_height = Sum(Mapped({s->s.size.height}, wins_size.up   + wins_size.down))  + original_height

  if len(wins_size.left + wins_size.right) == 0
    let new_desired_width = original_width
    let width_ratio = 1.0
  else
    let new_desired_width  = Max([Min([original_width*ratio,  total_width]),0])
    let width_ratio = 1.0 * (total_width  - new_desired_width)  / (total_width  - original_width)
  endif

  if len(wins_size.up + wins_size.down) == 0
    let new_desired_height = original_height
    let height_ratio = 1.0
  else
    let new_desired_height = Max([Min([original_height*ratio, total_height]),0])
    let height_ratio = 1.0 * (total_height - new_desired_height) / (total_height - original_height)
  endif

  let resized = MappedValues({v->Mapped({w->Resized(width_ratio, height_ratio, w)},v)}, wins_size)

  let new_desired_size = {
  \  'window': win,
  \  'size':   {
  \    'width':  new_desired_width,
  \    'height': new_desired_height
  \  }
  \}

  for w in Reversed(resized.left) + [new_desired_size] + resized.right | call ResizeWindow(w['window'], 'x', w['size']['width'])  | endfor
  for w in Reversed(resized.up)   + [new_desired_size] + resized.down  | call ResizeWindow(w['window'], 'y', w['size']['height']) | endfor

  call win_gotoid(win)

  let current_size = GetSize()
  if current_size[win].width != g:embiggen.last_size[win].width || current_size[win].height != g:embiggen.last_size[win].height
    let g:embiggen.zoom = zoom
  endif

  let g:embiggen.last_size = current_size
endfunction
