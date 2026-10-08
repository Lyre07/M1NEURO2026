1;  % Marks this file as an executable script so functions below are parsed before main code execution
% =========================================================================
% PROGRAM   : DOOM FPS MINI - Hellish Dimension Campaign
% FILE      : doom_fps_campaign_VF.m
% =========================================================================
%
% -------------------------------------------------------------------------
% 1. GOAL
% -------------------------------------------------------------------------
%   Escape the hellish mazes! Survive against hostile aberrations, scavenge
%   ammunition, and break through the green portals to reach safety.
%
% -------------------------------------------------------------------------
% 2. GAME COMPONENTS
% -------------------------------------------------------------------------
%   - 3D Raycasting Engine: Pseudo-3D rendering with lighting attenuation.
%   - Radar Minimap: Top-down tactical overview of the maze.
%   - Enemies & Hazards: Procedural demon shapes and exploding floor spikes.
%   - Combat System: Hitscan shooting with animated 2-frame weapon recoil.
%   - Audio: Procedural old-school chiptune square-wave bassline.
%
% -------------------------------------------------------------------------
% 3. VARIABLES
% -------------------------------------------------------------------------
%   - map                 : Grid matrix (1 = wall, 0 = walkable corridor, 2 = portal).
%   - player_x, player_y  : Space marine's 2D coordinates in the maze.
%   - player_angle        : Camera yaw / view heading angle (in radians).
%   - demon_x, demon_y    : Coordinate vectors of surviving demons.
%   - demon_hp            : Remaining health points per demon.
%   - trap_x, trap_y      : Coordinate vectors of hidden floor spikes.
%   - health, ammo, kills : Player status tracking metrics.
%   - levels_cleared      : Count of conquered hellish realms (target: 4).
%   - flash_timer         : Frame countdown for muzzle flash and recoil.
%
% -------------------------------------------------------------------------
% 4. MAIN LOOP
% -------------------------------------------------------------------------
%   - Polls keyboard state (movement, strafing, turning, hitscan fire).
%   - Advances demon chase vectors toward the marine with wall sliding.
%   - Resolves monster contact bites and floor trap explosions.
%   - Raycasts visual frame, renders sprites and weapon animations.
%   - Checks win condition (touching portal) or defeat (health <= 0).
%
% -------------------------------------------------------------------------
% 5. ACROSS TRIALS
% -------------------------------------------------------------------------
%   - Randomly selects starting realm theme and dynamically generates a new
%     procedural maze on each level via Randomized DFS.
%   - Carries over accumulated kills, grants +25 health bonuses upon
%     clearing a stage, and requires 4 consecutive wins for the final trophy.
%   - Replay option fully resets and loops the entire campaign structure.
%
% -------------------------------------------------------------------------
% 6. RULES
% -------------------------------------------------------------------------
%   - Start with 100 Health and 18 Ammo.
%   - Firing costs 1 bullet. Demons require 3-4 hits to kill.
%   - Slaying an aberration yields +4 to +5 ammunition loot.
%   - Demon melee deals -10 health; Traps deal -15 health.
%   - Clear 4 distinct hellish realms by stepping onto the green exit portal.
%   - Reaching 0 health triggers instant campaign failure.
%
% -------------------------------------------------------------------------
% 7. WAYS TO MOVE
% -------------------------------------------------------------------------
%   - Z / S             : Walk forward / backward.
%   - Q / D             : Strafe left / right.
%   - Left / Right keys : Turn camera (yaw).
%   - Spacebar          : Shoot weapon.
%   - Esc or X          : Stop/Quit the game.
%
% -------------------------------------------------------------------------
% 8. CONTEXT OF THIS GAME
% -------------------------------------------------------------------------
%   You are an elite Space Marine dispatched on an exploratory reconnaissance
%   mission to the uncharted exoplanet Beachasop. An anomalous spatial rift
%   cast you into a nightmare hellish dimension. You must fight your way
%   through 4 shifting domains to breach the planetary gateway.
%
% -------------------------------------------------------------------------
% 9. SOURCES (AI / SOUND / IMAGE / WORD LIST)
% -------------------------------------------------------------------------
%   - Source of AI      : Claude (Anthropic) for initial prototype; Gemini (Google)
%                         for procedural DFS algorithm, multi-stage, UI, and audio.
%   - Sound             : Procedural Old-School Chiptune Bassline (square waves).
%   - Images            : All images, HUD, weapon animations, and shapes are
%                         original, procedurally rendered mathematically.
%   - Word List         : None used.
%
% -------------------------------------------------------------------------
% 10. OCTAVE VERSION & CODE VERSION
% -------------------------------------------------------------------------
%   - Octave Version    : GNU Octave 9.x (check yours with: version)
%   - Code Version      : VF (Final Version)
%
% -------------------------------------------------------------------------
% 11. AUTHORS & CONTRIBUTION
% -------------------------------------------------------------------------
%   - Camil             : Co-concept designer, gameplay mechanics & combat logic.
%   - Bela              : Co-concept designer, procedural maze architecture & visuals.
%
% -------------------------------------------------------------------------
% 12. DATE
% -------------------------------------------------------------------------
%   - Date              : 08/10/2026
%                         (dd/mm/yyyy)
%
% =========================================================================

% ------------------------- FUNCTIONS -------------------------------------

function bgm_player = start_music()
  % Procedurally generates and plays a heavy, old-school chiptune bassline (E1M1 style)
  try
    Fs = 8000;
    t = 0 : 1/Fs : (0.115 - 1/Fs); % 16th note duration with a slight staccato cutoff
    gap = zeros(1, round(Fs * 0.01)); % Brief silence between notes

    fE = 82.41; fE_oct = 164.81; fD = 146.83; fC = 130.81; fBb = 116.54; fB = 123.47;
    riff = [fE, fE, fE_oct, fE, fE, fD, fE, fE, fC, fE, fE, fBb, fE, fE, fB, fC];

    bar_wave = [];
    env = exp(-6 * t); % Aggressive envelope decay for plucky bass sound
    for f = riff
      note = sign(sin(2 * pi * f * t)) .* env; % Gritty square wave
      bar_wave = [bar_wave, note, gap];
    endfor

    full_wave = repmat(bar_wave, 1, 64); % Loop the riff ~64 times (approx 2 minutes)
    full_wave = 0.1 * full_wave; % Keep volume low so it acts as background music

    bgm_player = audioplayer(full_wave, Fs);
    play(bgm_player);
  catch
    bgm_player = []; % Fallback if audio hardware is unavailable/unsupported
  end
endfunction

function key_press(src, evt)
  % Callback executed whenever a key is pressed down on the figure window
  held = getappdata(src, 'held');
  if isempty(held), held = {}; endif
  if ~any(strcmp(held, evt.Key))
    held{end+1} = evt.Key;
  endif
  setappdata(src, 'held', held);
  setappdata(src, 'last_key', evt.Key);
endfunction

function key_release(src, evt)
  % Callback executed whenever a key is released by the player
  held = getappdata(src, 'held');
  if isempty(held), held = {}; endif
  held(strcmp(held, evt.Key)) = [];
  setappdata(src, 'held', held);
endfunction

function key = wait_for_key(fig, valid_keys)
  % Pauses execution and waits synchronously until a key in valid_keys is pressed
  key = '';
  setappdata(fig, 'last_key', '');
  while ishandle(fig)
    pause(0.05);
    k = getappdata(fig, 'last_key');
    if any(strcmp(k, valid_keys))
      key = k;
      return;
    endif
  endwhile
endfunction

function r = is_held(held, names)
  % Returns 1.0 if any key specified in 'names' is currently held down, else 0.0
  r = double(any(ismember(held, names)));
endfunction

function themes = get_level_themes()
  % Defines visual attributes, color schemes, and enemy stats for each realm
  themes = {};

  % 1: Infernal Crypt
  themes{1}.name          = 'Infernal Crypt';
  themes{1}.wall_col      = [0.58, 0.16, 0.12];    
  themes{1}.ceil_col      = [0.08, 0.03, 0.03];
  themes{1}.floor_col     = [0.22, 0.14, 0.12];
  themes{1}.demon_body    = [0.95, 0.15, 0.15];    
  themes{1}.demon_eye     = [1.00, 0.90, 0.10];    
  themes{1}.demon_hp      = 3;                     
  themes{1}.demon_speed   = 0.8;                   % Significantly slower
  themes{1}.demon_shape   = 1;                     % Blocky/Classic
  themes{1}.ammo_loot     = 4;                     
  themes{1}.n_demons      = 6;                     

  % 2: Toxic Sewers
  themes{2}.name          = 'Toxic Sewers';        
  themes{2}.wall_col      = [0.12, 0.42, 0.22];    
  themes{2}.ceil_col      = [0.02, 0.07, 0.03];    
  themes{2}.floor_col     = [0.10, 0.22, 0.12];    
  themes{2}.demon_body    = [0.20, 0.95, 0.30];    
  themes{2}.demon_eye     = [1.00, 0.20, 0.85];    
  themes{2}.demon_hp      = 3;                     
  themes{2}.demon_speed   = 0.9;                   % Slower
  themes{2}.demon_shape   = 2;                     % Slender Ghoul
  themes{2}.ammo_loot     = 4;                     
  themes{2}.n_demons      = 7;                     

  % 3: Frozen Abyss
  themes{3}.name          = 'Frozen Abyss';        
  themes{3}.wall_col      = [0.15, 0.30, 0.60];    
  themes{3}.ceil_col      = [0.02, 0.04, 0.10];    
  themes{3}.floor_col     = [0.12, 0.18, 0.30];    
  themes{3}.demon_body    = [0.35, 0.85, 1.00];    
  themes{3}.demon_eye     = [1.00, 1.00, 1.00];    
  themes{3}.demon_hp      = 4;                     
  themes{3}.demon_speed   = 1.0;                   % Slower
  themes{3}.demon_shape   = 3;                     % Diamond/Floating
  themes{3}.ammo_loot     = 5;                     
  themes{3}.n_demons      = 7;                     

  % 4: Void Sanctuary
  themes{4}.name          = 'Void Sanctuary';      
  themes{4}.wall_col      = [0.38, 0.12, 0.50];    
  themes{4}.ceil_col      = [0.05, 0.02, 0.07];    
  themes{4}.floor_col     = [0.18, 0.10, 0.22];    
  themes{4}.demon_body    = [0.85, 0.25, 0.95];    
  themes{4}.demon_eye     = [0.20, 1.00, 0.90];    
  themes{4}.demon_hp      = 4;                     
  themes{4}.demon_speed   = 1.1;                   % Tactical speed
  themes{4}.demon_shape   = 4;                     % V-shape Stalker
  themes{4}.ammo_loot     = 5;                     
  themes{4}.n_demons      = 8;                     
endfunction

function map = generate_random_maze(nr, nc)
  map = ones(nr, nc);                              

  start_r = 2;                                     
  start_c = 2;                                     
  map(start_r, start_c) = 0;                       

  stack_r = [start_r];                             
  stack_c = [start_c];                             

  while ~isempty(stack_r)                          
    cr = stack_r(end);                             
    cc = stack_c(end);                             

    dr = [-2, 2,  0, 0];                           
    dc = [ 0, 0, -2, 2];                           
    valid = [];                                    
    for i = 1:4                                    
      nr_pos = cr + dr(i);                         
      nc_pos = cc + dc(i);                         
      if nr_pos >= 2 && nr_pos <= nr-1 && nc_pos >= 2 && nc_pos <= nc-1
        if map(nr_pos, nc_pos) == 1                
          valid(end+1) = i;                        
        endif
      endif
    endfor

    if ~isempty(valid)                             
      chosen = valid(randi(numel(valid)));         
      wr = cr + dr(chosen) / 2;                    
      wc = cc + dc(chosen) / 2;                    
      next_r = cr + dr(chosen);                    
      next_c = cc + dc(chosen);                    

      map(wr, wc) = 0;                             
      map(next_r, next_c) = 0;                     

      stack_r(end+1) = next_r;                     
      stack_c(end+1) = next_c;                     
    else
      stack_r(end) = [];                           
      stack_c(end) = [];                           
    endif
  endwhile

  [wr, wc] = find(map(2:nr-1, 2:nc-1) == 1);       
  wr = wr + 1; wc = wc + 1;                        
  if numel(wr) > 5                                 
    p = randperm(numel(wr), min(4, numel(wr)));    
    for i = p                                      
      map(wr(i), wc(i)) = 0;                       
    endfor
  endif

  map(2, 2) = 0;                                   
  map(2, 3) = 0;                                   
  map(nr-1, nc-1) = 0;                             
  map(nr-1, nc)   = 2;                             
endfunction

function ok = can_walk(map, x, y, margin)
  [nr, nc] = size(map);                            
  xs = [x - margin, x + margin, x - margin, x + margin]; 
  ys = [y - margin, y - margin, y + margin, y + margin]; 
  ci = floor(xs) + 1;                              
  ri = floor(ys) + 1;                              
  if any(ci < 1 | ci > nc | ri < 1 | ri > nr)      
    ok = false;                                    
    return;                                        
  endif
  ok = all(map(sub2ind([nr nc], ri, ci)) == 0);    
endfunction

function d = wall_distance(map, px, py, angle)
  [nr, nc] = size(map);                            
  d = 14;                                          
  for t = 0.04:0.04:14                             
    ci = floor(px + t * cos(angle)) + 1;           
    ri = floor(py + t * sin(angle)) + 1;           
    if ci < 1 || ci > nc || ri < 1 || ri > nr || map(ri, ci) > 0 
      d = t;                                       
      return;                                      
    endif
  endfor
endfunction

function img = render_frame(map, px, py, angle, ex, ey, tx, ty, img_w, img_h, fov, cfg, flash_timer)
  [nr, nc] = size(map);                            
  step    = 0.04;                                  
  max_d   = 14;                                    
  offsets = linspace(-fov/2, fov/2, img_w);        
  rays    = angle + offsets;                       
  D = (step:step:max_d)';                          
  X = px + D * cos(rays);                          
  Y = py + D * sin(rays);                          
  ci = min(max(floor(X) + 1, 1), nc);              
  ri = min(max(floor(Y) + 1, 1), nr);              
  cells = map(sub2ind([nr nc], ri, ci));           
  [anyhit, idx] = max(cells > 0, [], 1);           
  idx(~anyhit) = numel(D);                         
  lin = idx + (0:img_w-1) * numel(D);              
  wall_dist = D(idx)';                             
  wall_type = cells(lin);                          
  wall_type(~anyhit) = 1;                          
  xh = X(lin);                                     
  yh = Y(lin);                                     

  % Wall shading and vertical faux-brick texture striping
  fx = min(mod(xh, 1), 1 - mod(xh, 1));            
  fy = min(mod(yh, 1), 1 - mod(yh, 1));            
  face_x = fx < fy;                                
  u = mod(face_x .* yh + (~face_x) .* xh, 1);      
  stripe = u < 0.06;                               
  shade = (1 ./ (1 + 0.15 * wall_dist)) .* (0.75 + 0.25 * face_x) .* (1 - 0.4 * stripe); 
  base_wall = cfg.wall_col;                        
  base_exit = [0.10, 0.95, 0.25];                  
  wall_h = img_h ./ max(wall_dist .* cos(offsets), 0.1); 
  R = (1:img_h)';                                  
  mask = abs(R - (img_h + 1)/2) <= wall_h / 2;     

  img = zeros(img_h, img_w, 3);                    
  ceil_c  = cfg.ceil_col;                          
  floor_c = cfg.floor_col;                         
  for ch = 1:3                                     
    bg = (R <= img_h/2) * ceil_c(ch) + (R > img_h/2) .* floor_c(ch) .* (0.3 + 0.7 * (R - img_h/2) / (img_h/2));
    wall_col = ((wall_type == 1) * base_wall(ch) + (wall_type == 2) * base_exit(ch)) .* shade;
    img(:, :, ch) = bg .* (~mask) + mask .* wall_col; 
  endfor

  % Combine demons and traps for depth sorting
  if ~isempty(ex) || ~isempty(tx)
    ent_x = [ex(:); tx(:)];
    ent_y = [ey(:); ty(:)];
    ent_type = [ones(numel(ex),1); 2*ones(numel(tx),1)]; % 1 = Demon, 2 = Trap
    
    dx = ent_x - px;
    dy = ent_y - py;
    dist = hypot(dx, dy);
    rel = mod(atan2(dy, dx) - angle + pi, 2*pi) - pi;
    [~, order] = sort(dist, 'descend');
    
    for k = order(:)'
      if abs(rel(k)) > fov/2 + 0.4 || dist(k) < 0.2
        continue;
      endif
      
      center_col = (rel(k) / (fov/2)) * (img_w/2) + (img_w + 1)/2;
      s = 1 / (1 + 0.15 * dist(k));
      
      if ent_type(k) == 1
        % ---- DEMON RENDERING (With distinct shapes) ----
        sprite_h = img_h * 0.7 / max(dist(k) * cos(rel(k)), 0.1);
        sprite_w = sprite_h * 0.5;
        top_row = (img_h + 1)/2 - sprite_h/2;
        cols = max(1, round(center_col - sprite_w/2)):min(img_w, round(center_col + sprite_w/2));
        eye_rows = max(1, round(top_row + 0.25 * sprite_h)):min(img_h, round(top_row + 0.25 * sprite_h) + 1);
        
        body_c = cfg.demon_body;
        eye_c  = cfg.demon_eye;
        
        for c = cols
          if dist(k) < wall_dist(c)
            % Procedural shaping based on realm config
            nx = abs(c - center_col) / (sprite_w/2);
            
            if cfg.demon_shape == 2      % Slender
              if nx > 0.4; continue; endif
              col_rows = max(1, round(top_row)):min(img_h, round(top_row + sprite_h));
            elseif cfg.demon_shape == 3  % Diamond
              y_margin = nx * (sprite_h/2);
              col_rows = max(1, round(top_row + y_margin)):min(img_h, round(top_row + sprite_h - y_margin));
            elseif cfg.demon_shape == 4  % V-shape Stalker
              y_top = top_row + (1-nx)*0.5*sprite_h;
              y_bot = top_row + sprite_h - nx*0.5*sprite_h;
              col_rows = max(1, round(y_top)):min(img_h, round(y_bot));
            else                         % Classic Blocky
              col_rows = max(1, round(top_row)):min(img_h, round(top_row + sprite_h));
            endif
            
            if isempty(col_rows); continue; endif;
            
            img(col_rows, c, 1) = body_c(1) * s;
            img(col_rows, c, 2) = body_c(2) * s;
            img(col_rows, c, 3) = body_c(3) * s;
            
            if abs(nx - 0.4) < 0.15
              img(eye_rows, c, 1) = eye_c(1);
              img(eye_rows, c, 2) = eye_c(2);
              img(eye_rows, c, 3) = eye_c(3);
            endif
          endif
        endfor
        
      else
        % ---- TRAP RENDERING (Floor Spikes) ----
        trap_h = (img_h * 0.25) / max(dist(k) * cos(rel(k)), 0.1);
        trap_w = trap_h * 0.8; % Narrowed to reflect the smaller, avoidable hitbox
        top_row = (img_h + 1)/2 + (img_h * 0.35) / max(dist(k) * cos(rel(k)), 0.1) - trap_h; % Anchored to floor
        cols = max(1, round(center_col - trap_w/2)):min(img_w, round(center_col + trap_w/2));
        
        for c = cols
          if dist(k) < wall_dist(c)
            nx = abs(c - center_col) / (trap_w/2);
            y_top = top_row + nx * trap_h; % Pointy top
            col_rows = max(1, round(y_top)):min(img_h, round(top_row + trap_h));
            
            if ~isempty(col_rows)
              img(col_rows, c, 1) = 0.9 * s; % Orange/Red warning color
              img(col_rows, c, 2) = 0.4 * s;
              img(col_rows, c, 3) = 0.1 * s;
            endif
          endif
        endfor
      endif
    endfor
  endif

  % ---- Weapon Rendering & 2-Frame Animation ----
  gun_c = round(img_w / 2);
  gun_r = img_h;
  
  if flash_timer > 0
    g_off_r = 3;  % Recoil pushes gun down
    g_off_c = 1;  % Recoil pushes gun slightly right
  else
    g_off_r = 0;  % Idle position
    g_off_c = 0;
  endif
  
  for dr = -16:0
    for dc = -6:6
      r = gun_r + dr + g_off_r;
      c = gun_c + dc + g_off_c;
      if r > 0 && r <= img_h && c > 0 && c <= img_w
        if dr >= -8 && abs(dc) <= 5
          img(r, c, 1) = 0.25; img(r, c, 2) = 0.25; img(r, c, 3) = 0.25;
        elseif dr >= -16 && abs(dc) <= 2
          img(r, c, 1) = 0.15; img(r, c, 2) = 0.15; img(r, c, 3) = 0.15;
          if dr <= -12 && abs(dc) <= 1
            img(r, c, 1) = 0.05; img(r, c, 2) = 0.05; img(r, c, 3) = 0.05;
          endif
        endif
      endif
    endfor
  endfor
  
  % Red dot sight
  for dr = -17:-15
    r = gun_r + dr + g_off_r;
    c = gun_c + g_off_c;
    if r > 0 && r <= img_h && c > 0 && c <= img_w
      img(r, c, 1) = 0.9; img(r, c, 2) = 0.1; img(r, c, 3) = 0.1;
    endif
  endfor

  % Muzzle flash overlay (drawn only when firing)
  if flash_timer > 0
    for dr = -23:-16
      for dc = -5:5
        if abs(dc) + abs(dr + 19) <= 5 
          r = gun_r + dr + g_off_r;
          c = gun_c + dc + g_off_c;
          if r > 0 && r <= img_h && c > 0 && c <= img_w
            img(r, c, 1) = 1.0; img(r, c, 2) = 0.8; img(r, c, 3) = 0.1; % Bright orange/yellow flash
          endif
        endif
      endfor
    endfor
  endif

  % Tactical radar minimap
  sc = 2;                                          
  wallm = kron(double(map == 1), ones(sc));        
  exitm = kron(double(map == 2), ones(sc));        
  mm = zeros(nr * sc, nc * sc, 3);                 
  mm(:, :, 1) = cfg.wall_col(1) * 0.7 * wallm;     
  mm(:, :, 2) = cfg.wall_col(2) * 0.7 * wallm + 0.9 * exitm; 
  mm(:, :, 3) = cfg.wall_col(3) * 0.7 * wallm;     
  
  for k = 1:numel(tx)                              
    r = min(max(floor(ty(k) * sc) + 1, 1), nr * sc); 
    c = min(max(floor(tx(k) * sc) + 1, 1), nc * sc); 
    mm(r, c, :) = reshape([1.0 0.5 0.0], 1, 1, 3); % Orange trap blips
  endfor
  for k = 1:numel(ex)                              
    r = min(max(floor(ey(k) * sc) + 1, 1), nr * sc); 
    c = min(max(floor(ex(k) * sc) + 1, 1), nc * sc); 
    mm(r, c, :) = reshape(cfg.demon_body, 1, 1, 3);
  endfor
  
  r = min(max(floor(py * sc) + 1, 1), nr * sc);    
  c = min(max(floor(px * sc) + 1, 1), nc * sc);    
  mm(r, c, :) = reshape([1 1 1], 1, 1, 3);         
  img(1:nr*sc, 1:nc*sc, :) = mm;                   
endfunction

function save_result(filename, kills, outcome, seconds, levels_cleared)
  fid = fopen(filename, 'a');                      
  fprintf(fid, '%s | cleared = %d/4 | kills = %d | %s | %.1f s\n', ...
          datestr(now, 'yyyy-mm-dd HH:MM:SS'), levels_cleared, kills, outcome, seconds); 
  fclose(fid);                                     
endfunction

% ------------------------- SETUP -----------------------------------------
clear; clc; close all;                             

bgm_player     = start_music();                    % Initialize and start background track
all_themes     = get_level_themes();               
img_w          = 120;                              
img_h          = 72;                               
fov            = 1.05;                             
move_speed     = 2.6;                              
turn_speed     = 2.2;                              
demon_wake     = 6.0;                              
start_health   = 100;                              
start_ammo     = 18;                               
results_file   = 'doom_fps_results.txt';           

fig = figure('Name', 'DOOM FPS MINI - Hellish Dimension Campaign', 'NumberTitle', 'off', ...
             'Color', [0.08 0.02 0.02], 'KeyPressFcn', @key_press, 'KeyReleaseFcn', @key_release);
ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.05 0.05 0.90 0.82], ...
          'XTick', [], 'YTick', [], 'Box', 'on');   
h_img = image(ax, zeros(img_h, img_w, 3));         
axis(ax, 'image');                                 
hold(ax, 'on');                                    
plot(ax, (img_w + 1)/2, (img_h + 1)/2, '+', 'MarkerSize', 14, 'Color', 'w'); 

% ------------------------- ACROSS CAMPAIGNS LOOP -------------------------
disp('================================================');
disp(' PHASE : BEGINNING (Loading Title Screens...)');
disp('================================================');
play_again = true;                                 
while play_again && ishandle(fig)                  

  health         = start_health;                   
  ammo           = start_ammo;                     
  kills          = 0;                              
  levels_cleared = 0;                              
  required_wins  = 4;                              
  campaign_won   = false;                          
  campaign_timer = tic;                            

  theme_idx = randi(numel(all_themes));            

  % ---- Title Screen (Credits & Metadata) ----
  dummy_cfg = all_themes{theme_idx};               
  preview_map = generate_random_maze(15, 15);      
  set(h_img, 'CData', render_frame(preview_map, 1.5, 1.5, 0, [], [], [], [], img_w, img_h, fov, dummy_cfg, 0)); 
  title(ax, 'DOOM FPS MINI - VF', 'Color', 'y');   
  title_text = text(ax, (img_w + 1)/2, (img_h + 1)/2, { ...
                '=====================================', ...
                '        DOOM FPS MINI (VF)           ', ...
                '=====================================', ...
                'Authors : Camil & Bela', ...
                'Role    : Co-concept Designers', ...
                'Date    : 08/10/2026 (dd/mm/yyyy)', ...
                'Engine  : GNU Octave (Latest 9.x)', ...
                'AI Tools: Claude & Gemini', ...
                'Visuals : 100% Original Procedural Graphics', ...
                '=====================================', ...
                '', ...
                'Press SPACE to Continue' ...
               }, ...
               'HorizontalAlignment', 'center', 'Color', 'y', 'FontSize', 9, ...
               'FontName', 'monospace', 'BackgroundColor', 'k'); 
  key = wait_for_key(fig, {'space', 'q', 'x', 'escape'}); 
  if ishandle(title_text), delete(title_text); endif 
  if isempty(key) || any(strcmp(key, {'q', 'x', 'escape'})) 
    break;                                         
  endif

  % ---- Mission Briefing & Explanation Screen ----
  title(ax, 'MISSION: ESCAPE PLANET BEACHASOP', 'Color', 'y'); 
  rules = text(ax, (img_w + 1)/2, (img_h + 1)/2, {'MISSION BRIEFING', ...
                'Stranded in a hellish dimension on Planet Beachasop!', ...
                'Escape 4 procedural mazes by reaching the GREEN PORTALS.', ...
                'Watch out for EXPLODING SPIKE TRAPS on the floor!', ...
                'Demons require 3-4 hits and drop +4 to +5 ammunition.', '', ...
                'Z/S: Walk   Q/D: Strafe   Left/Right: Turn   Space: Shoot', '', ...
                'Press SPACE to Begin Your Escape'}, ...
               'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 10, ...
               'BackgroundColor', 'k');            
  key = wait_for_key(fig, {'space', 'q', 'x', 'escape'}); 
  if ishandle(rules), delete(rules); endif         
  if isempty(key) || any(strcmp(key, {'q', 'x', 'escape'})) 
    break;                                         
  endif

  disp('================================================');
  disp(' PHASE : GAME (Entering Labyrinth...)');
  disp('================================================');
  
  % ---- Campaign Progression Loop (Levels 1 to 4) ----
  while levels_cleared < required_wins && ishandle(fig) 
    cfg = all_themes{theme_idx};                   

    map = generate_random_maze(15, 15);            
    [exit_row, exit_col] = find(map == 2);         
    exit_x = exit_col - 0.5;                       
    exit_y = exit_row - 0.5;                       

    player_x     = 1.5;                            
    player_y     = 1.5;                            
    player_angle = 0;                              
    flash_timer  = 0;                              

    % Spawn demon enemies
    [free_r, free_c] = find(map == 0);             
    far_enough = hypot(free_c - 0.5 - player_x, free_r - 0.5 - player_y) > 5; 
    free_r_d = free_r(far_enough);                   
    free_c_d = free_c(far_enough);                   
    pick_d = randperm(numel(free_r_d), min(cfg.n_demons, numel(free_r_d))); 
    demon_x  = free_c_d(pick_d)' - 0.5;                
    demon_y  = free_r_d(pick_d)' - 0.5;                
    demon_hp = repmat(cfg.demon_hp, 1, numel(demon_x)); 

    % Spawn floor traps (spikes)
    far_enough_t = hypot(free_c - 0.5 - player_x, free_r - 0.5 - player_y) > 3; 
    free_r_t = free_r(far_enough_t);
    free_c_t = free_c(far_enough_t);
    pick_t = randperm(numel(free_r_t), min(5, numel(free_r_t)));
    trap_x = free_c_t(pick_t)' - 0.5;
    trap_y = free_r_t(pick_t)' - 0.5;

    setappdata(fig, 'last_key', '');               
    setappdata(fig, 'held', {});                   

    stage_running = true;                          
    stage_outcome = 'stopped';                     
    frame_clock = tic;                             

    % ---- Main Game Frame Loop ----
    while stage_running && ishandle(fig)           
      held = getappdata(fig, 'held');              
      key  = getappdata(fig, 'last_key');          
      setappdata(fig, 'last_key', '');             
      dt = min(toc(frame_clock), 0.1);             
      frame_clock = tic;                           

      % Calculate AZERTY movement
      move_fwd  = move_speed * dt * (is_held(held, {'w', 'z'}) - is_held(held, {'s'})); 
      move_side = move_speed * dt * (is_held(held, {'d'}) - is_held(held, {'a', 'q'})); 
      player_angle = player_angle + turn_speed * dt * ...
                     (is_held(held, {'rightarrow', 'right'}) - is_held(held, {'leftarrow', 'left'})); 

      % Shooting & hitscan combat logic
      if strcmp(key, 'space') && ammo > 0          
        ammo = ammo - 1;                           
        flash_timer = 2;                           % Triggers muzzle flash and recoil frame
        dx = demon_x - player_x;                   
        dy = demon_y - player_y;                   
        dist = hypot(dx, dy);                      
        rel = mod(atan2(dy, dx) - player_angle + pi, 2*pi) - pi; 
        visible = dist < wall_distance(map, player_x, player_y, player_angle); 
        candidates = find(abs(rel) < pi/2 & abs(sin(rel)) .* dist < 0.45 & visible); 
        if ~isempty(candidates)                    
          [~, nearest] = min(dist(candidates));    
          victim = candidates(nearest);            
          demon_hp(victim) = demon_hp(victim) - 1; 
          if demon_hp(victim) <= 0                 
            demon_x(victim)  = [];                 
            demon_y(victim)  = [];                 
            demon_hp(victim) = [];                 
            kills = kills + 1;                     
            ammo  = ammo + cfg.ammo_loot;          
          endif
        endif
      elseif any(strcmp(key, {'escape', 'x'}))     
        stage_outcome = 'stopped';                 
        stage_running = false;                     
        break;                                     
      endif

      % Player movement with axis-separated collision resolution
      new_x = player_x + move_fwd * cos(player_angle) - move_side * sin(player_angle); 
      new_y = player_y + move_fwd * sin(player_angle) + move_side * cos(player_angle); 
      if can_walk(map, new_x, player_y, 0.2), player_x = new_x; endif 
      if can_walk(map, player_x, new_y, 0.2), player_y = new_y; endif 

      % Demon pursuit AI
      for k = 1:numel(demon_x)                     
        dist_k = hypot(player_x - demon_x(k), player_y - demon_y(k)); 
        if dist_k < demon_wake                     
          new_dx = demon_x(k) + cfg.demon_speed * dt * (player_x - demon_x(k)) / dist_k; 
          new_dy = demon_y(k) + cfg.demon_speed * dt * (player_y - demon_y(k)) / dist_k; 
          if can_walk(map, new_dx, demon_y(k), 0.25), demon_x(k) = new_dx; endif 
          if can_walk(map, demon_x(k), new_dy, 0.25), demon_y(k) = new_dy; endif 
        endif
      endfor

      % Contact bites from demons
      bites = hypot(player_x - demon_x, player_y - demon_y) < 0.7; 
      if any(bites)                                
        health = health - 10 * sum(bites);         
        demon_x(bites)  = [];                      
        demon_y(bites)  = [];                      
        demon_hp(bites) = [];                      
      endif

      % Trap explosions
      trap_hits = hypot(player_x - trap_x, player_y - trap_y) < 0.2; % Radius reduced to allow wall-hugging evasion
      if any(trap_hits)
        health = health - 15 * sum(trap_hits);     % Massive damage from stepping on trap
        trap_x(trap_hits) = [];                    % Trap is destroyed
        trap_y(trap_hits) = [];
      endif

      % Render current 3D frame and HUD
      frame = render_frame(map, player_x, player_y, player_angle, demon_x, demon_y, trap_x, trap_y, img_w, img_h, fov, cfg, flash_timer);
      if flash_timer > 0                           
        frame = min(frame + 0.25, 1);              % Environmental flash
        flash_timer = flash_timer - 1;             
      endif
      set(h_img, 'CData', frame);                  
      title(ax, sprintf('[Realm %d/4: %s]  HP: %d  Ammo: %d  Kills: %d  Demons: %d', ...
                        levels_cleared + 1, cfg.name, health, ammo, kills, numel(demon_x)), 'Color', 'y'); 
      drawnow;                                     
      pause(0.01);                                 

      % Keep music looping if it finishes
      if ~isempty(bgm_player) && ~isplaying(bgm_player)
        play(bgm_player);
      endif

      % Evaluate stage progression conditions
      if hypot(player_x - exit_x, player_y - exit_y) < 1.3 
        stage_outcome = 'stage_win';               
        stage_running = false;                     
      elseif health <= 0                           
        stage_outcome = 'lose';                    
        stage_running = false;                     
      endif
    endwhile

    if ~ishandle(fig) || strcmp(stage_outcome, 'stopped') 
      break;                                       
    endif

    if strcmp(stage_outcome, 'stage_win')          
      levels_cleared = levels_cleared + 1;         
      health = min(100, health + 25);              
      if levels_cleared < required_wins            
        theme_idx = mod(theme_idx, numel(all_themes)) + 1; 
        inter_text = text(ax, (img_w + 1)/2, (img_h + 1)/2, ...
                          {sprintf('REALM %d CONQUERED!', levels_cleared), ...
                           '+25 Health Restored!', '', ...
                           sprintf('Next Dimension: %s', all_themes{theme_idx}.name), '', ...
                           'Press SPACE to Enter the Next Rift'}, ...
                          'HorizontalAlignment', 'center', 'Color', 'g', 'FontSize', 12, ...
                          'BackgroundColor', 'k'); 
        k = wait_for_key(fig, {'space', 'q', 'escape'}); 
        if ishandle(inter_text), delete(inter_text); endif 
        if any(strcmp(k, {'q', 'escape'}))         
          break;                                   
        endif
      else
        campaign_won = true;                       
      endif
    elseif strcmp(stage_outcome, 'lose')           
      break;                                       
    endif
  endwhile

  if ~ishandle(fig), break; endif                  

  % ---- Campaign Conclusion / Trophy & Results Screen ----
  disp('================================================');
  disp(' PHASE : END OF THE GAME (Results...)');
  disp('================================================');
  total_seconds = toc(campaign_timer);             
  if campaign_won                                  
    save_result(results_file, kills, 'VICTORY', total_seconds, levels_cleared); 

    trophy_msg = {'=======================================', ...
                  '            * * * CHAMPION * * *       ', ...
                  '                 .-========-.          ', ...
                  '                 \ -======- /          ', ...
                  '                 _|   .---. |_         ', ...
                  '                ((|  (| 1 |) |))       ', ...
                  '                 \|   `---\'' |/         ', ...
                  '                  \  TROPHY /          ', ...
                  '                   `---.---''          ', ...
                  '                      | |              ', ...
                  '                     (===)             ', ...
                  '=======================================', ...
                  '   ESCAPED PLANET BEACHASOP! ALL 4 REALMS BEATEN!  ', ...
                  sprintf('Total Kills: %d  |  Total Time: %.0f s', kills, total_seconds), '', ...
                  'Press  R  to Replay  or  Q  to Quit'}; 

    endtext = text(ax, (img_w + 1)/2, (img_h + 1)/2, trophy_msg, ...
                   'HorizontalAlignment', 'center', 'Color', [1 0.84 0], 'FontName', 'monospace', ...
                   'FontSize', 9, 'BackgroundColor', 'k'); 
  else                                             
    save_result(results_file, kills, 'DEFEAT', total_seconds, levels_cleared); 
    endtext = text(ax, (img_w + 1)/2, (img_h + 1)/2, ...
                   {'M.I.A. IN THE HELLISH DIMENSION', ...
                    sprintf('Realms Escaped: %d / 4', levels_cleared), ...
                    sprintf('Kills: %d  |  Time: %.0f s', kills, total_seconds), '', ...
                    'Press  R  to Retry  or  Q  to Quit'}, ...
                   'HorizontalAlignment', 'center', 'Color', 'r', 'FontSize', 12, ...
                   'BackgroundColor', 'k');        
  endif

  key = wait_for_key(fig, {'r', 'q', 'escape'});   
  if ishandle(endtext), delete(endtext); endif     
  play_again = strcmp(key, 'r');                   
endwhile

if ~isempty(bgm_player) && isplaying(bgm_player), stop(bgm_player); endif
if ishandle(fig), close(fig); endif                
disp('Mission concluded. Results recorded in doom_fps_results.txt'); 
