-- HABITUS WORKSHOP:
-- Reflecting on streams

_r = require 'reflection'
g = grid.connect()

function init()
  grid_connected = g.device~= nil and true or false -- ternary operator, eg. http://lua-users.org/wiki/TernaryOperator
  init_patterns()
end

function init_patterns()
  -- we are creating 8 pattern slots
  debug = false
  monitor_inputs = false
  -- _norns.vu outputs values from 0 to 63, but doesn't account for clipping, so we set a reasonable max value
  max_amp = 40
  input_levels = { l = 0, r = 0 }
  patterns = {}
  currently_recording = {}
  for i=1,8 do
    patterns[i] = _r.new()
    patterns[i].process = parse_pattern
    patterns[i]:set_loop(1)
    currently_recording[i] = patterns[i].rec_enabled == 1
  end
end

function parse_pattern(event)
  if debug then
    print("L: " .. event.value.l .. " R: " .. event.value.r)
  end
  grid_redraw(2, event.id, clamp_vu_values(event.value.l))
  grid_redraw(3, event.id, clamp_vu_values(event.value.r))
end

function redraw()
  print_pattern_status()
  print_info()
  print_input_levels()
  screen.update()
end

function print_pattern_status()
  screen.clear()
  for index, pattern in ipairs(patterns) do
    local vertical_offset = 7 * index
    local is_recording = pattern.rec == 1
    screen.move(0, vertical_offset)
    if is_recording then
      screen.text(index)
    end
    screen.move(10, vertical_offset)
    local is_playing = pattern.play == 1
    if pattern.step > 0 and pattern.count > 0 and is_playing then
      screen.text(pattern.step)
    end
  end
end

function print_input_levels()
  screen.move(64, 7)
  screen.text("Channel 1: " .. input_levels.l)
  screen.move(64, 14)
  screen.text("Channel 2: " .. input_levels.r)
end

function print_info()
  screen.move(64, 28)
  screen.text("K2: toggle all")
  screen.move(64, 35)
  screen.text("K3: erase all")
end

function key(n, z)
  if n == 2 and z == 1 then
    for index, pattern in ipairs(patterns) do
      if pattern.play == 1 then
        pattern:stop()
      else
        pattern:start()
      end
    end
  elseif n == 3 and z == 1 then
    for index, pattern in ipairs(patterns) do
      pattern:clear()
      grid_redraw()
    end
  end
end

-- 0 - 63
function _norns.vu(in1, in2, out1, out2)
  -- print(in1, in2, out1, out2)
  input_levels.l = in1
  input_levels.r = in2
  
  for index, status in ipairs(currently_recording) do
    if status then
      local event = {
        id = index,
        value = {
          l = input_levels.l,
          r = input_levels.r,
        }
      }
      patterns[index]:watch(event)
      parse_pattern(event)
    end
  end
  
  redraw()
  grid_redraw()
end

function clamp_vu_values(value)
  return util.round(util.linlin(0, max_amp, 0, 15, value))
end

function grid_redraw(x, y, level)
  if grid_connected then
    if monitor_inputs then
      g:led(g.cols - 1, 1, clamp_vu_values(input_levels.l))
      g:led(g.cols, 1, clamp_vu_values(input_levels.r))
    end
    
    if x and y and level then
      g:led(x, y, level)
    end 
    
    g:refresh()
  end
end

function g.key(x, y, z)
  if z == 1 and x == 1 then
    handle_column_1_keypress(x, y, z)
  end
end

function handle_column_1_keypress(x, y, z)
  -- DEBUG printy stuff, ignore
  local index = y
  if debug then
    print(index)
    print("is currently recording pattern " .. index .. "?")
    print(currently_recording[index])
    if currently_recording[index] then
      print("stopping recording of pattern " .. index)
      tab.print(patterns[index].event)
      print(patterns[index].play)
    else
      print("starting to record pattern " .. index)
    end
  end
  -- END DEBUG
  
  if currently_recording[index] then
    currently_recording[index] = false
    patterns[index]:set_rec(0)
  else 
    currently_recording[index] = true
    patterns[index]:set_rec(1)
  end
  
  local level = currently_recording[index] and 15 or 0
  grid_redraw(x, y, level)
end
