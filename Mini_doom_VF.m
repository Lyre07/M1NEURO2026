1;  % marks this file as a script (functions below are defined before use)
% =========================================================================
% PROGRAM   : DOOM FPS MINI - Hellish Dimension Campaign
% FILE      : doom_fps_campaign_VF.m
% =========================================================================
%
% -------------------------------------------------------------------------
% 1. GOAL
% -------------------------------------------------------------------------
%   You have to escape those hellish mazes! Trapped across 4 treacherous,
%   shifting realms, you must survive against hostile aberrations, scavenge
%   vital ammunition, and break through the green exit portals to reach
%   safety and claim the champion trophy.
%
% -------------------------------------------------------------------------
% 2. GAME COMPONENTS
% -------------------------------------------------------------------------
%   - Walking & Strafe    : Smooth 2D-to-3D projection movement with axis-by-axis
%                           wall sliding collisions.
%   - Raycasting 3D Engine: Mathematical ray-marching per image column with
%                           distance-based lighting attenuation and faux-brick texturing.
%   - Shooting & Combat   : Ray-traced hitscan targeting. Sturdy multi-hit demons
%                           yield ammunition caches upon defeat.
%   - Fleeing & Portals   : Dynamic evasion tactics against chasing predators while
%                           locating and rushing toward the luminous green portal.
%   - Radar Minimap       : Real-time top-down tactical overview showing player orientation,
%                           labyrinth layout, demon vectors, and portal exit location.
%
% -------------------------------------------------------------------------
% 3. VARIABLES
% -------------------------------------------------------------------------
%   - map                 : Grid matrix (1 = wall, 0 = walkable corridor, 2 = portal).
%   - player_x, player_y  : 2D coordinates of the space marine in the maze.
%   - player_angle        : Camera yaw / view heading angle (in radians).
%   - demon_x, demon_y    : Coordinate vectors of surviving hellish demons.
%   - demon_hp            : Remaining health points per demon (requires 3 to 4 shots).
%   - health, ammo, kills : Marine status tracking vitality, munitions, and eliminations.
%   - levels_cleared      : Count of conquered hellish realms (target: 4).
%   - flash_timer         : Frame countdown for muzzle flash lighting effect.
%
% -------------------------------------------------------------------------
% 4. MAIN LOOP & EXECUTION FLOW
% -------------------------------------------------------------------------
%   - Across-Campaign Loop: Randomly chooses starting realm, tracks total kills,
%                           elapsed campaign time, and transitions stages until defeat
%                           or 4-level victory trophy.
%   - Stage Generation    : Invokes randomized depth-first search backtracker to carve
%                           a unique, solvable labyrinth for each stage.
%   - Per-Frame Inner Loop:
%       1) Polls keyboard state (movement, strafing, turning, hitscan fire).
%       2) Advances demon chase vectors toward the marine with wall sliding.
%       3) Resolves monster contact bites and applies player damage.
%       4) Raycasts visual frame, renders billboard creatures, and paints radar map.
%       5) Checks win condition (touching portal) or defeat (health <= 0).
%
% -------------------------------------------------------------------------
% 5. RULES
% -------------------------------------------------------------------------
%   - Start with 100 Health and 18 Ammo.
%   - Firing costs 1 bullet. Demons require 3-4 hits to kill.
%   - Slaying an aberration yields +4 to +5 ammunition loot.
%   - Demon melee contact deals -10 to -12 health damage.
%   - Clear 4 distinct hellish realms by stepping onto the green exit portal.
%   - Reaching 0 health triggers instant campaign failure.
%
% -------------------------------------------------------------------------
% 6. CONTEXT & LORE
% -------------------------------------------------------------------------
%   You are an elite Space Marine dispatched on an exploratory reconnaissance
%   mission to the uncharted exoplanet Beachasop. During orbital descent, an
%   anomalous spatial rift tore your vessel apart and cast you into a nightmare
%   hellish dimension. To return to reality, you must fight your way through
%   4 shifting labyrinthine domains and breach the planetary gateway.
%
% -------------------------------------------------------------------------
% 7. SOURCES (AI / SOUND / IMAGE / WORD LIST)
% -------------------------------------------------------------------------
%   - Source of AI        : Initial prototype generated with Claude (Anthropic);
%                           Campaign structure, procedural DFS maze algorithm,
%                           and mechanics balancing developed with Gemini (Google).
%   - Sound               : None (pure visual rendering).
%   - Images              : All images and graphics are original, procedurally
%                           rendered in real-time via Octave matrices.
%   - Word List           : None.
%
% -------------------------------------------------------------------------
% 8. ENVIRONMENT & VERSIONS
% -------------------------------------------------------------------------
%   - Octave Version      : GNU Octave 9.x (check yours with: version)
%   - Code Version        : v3
%
% -------------------------------------------------------------------------
% 9. AUTHORS & CONTRIBUTIONS
% -------------------------------------------------------------------------
%   - Camil               : Co-concept designer, gameplay mechanics & combat logic.
%   - Bela                : Co-concept designer, procedural maze architecture & visuals.
%
% -------------------------------------------------------------------------
% 10. DATE
% -------------------------------------------------------------------------
%   - Date                : 01/10/2026
%                           (dd/mm/yyyy)
%
% =========================================================================

% ------------------------- FUNCTIONS -------------------------------------

function key_press(src, evt)
  % Callback executed whenever a key is pressed down on the figure window
  held = getappdata(src, 'held');                  % Retrieve list of currently held keys
  if isempty(held), held = {}; endif               % Initialize empty cell array if none exists
  if ~any(strcmp(held, evt.Key))                   % Check if key is not already registered as held
    held{end+1} = evt.Key;                         % Append key name to currently held keys list
  endif
  setappdata(src, 'held', held);                   % Save updated list of held keys in figure metadata
  setappdata(src, 'last_key', evt.Key);            % Record key as last one-shot event (for triggers)
endfunction

function key_release(src, evt)
  % Callback executed whenever a key is released by the player
  held = getappdata(src, 'held');                  % Retrieve list of currently held keys
  if isempty(held), held = {}; endif               % Guard against uninitialized state
  held(strcmp(held, evt.Key)) = [];                % Remove the released key from cell array
  setappdata(src, 'held', held);                   % Store updated held keys back into figure metadata
endfunction

function key = wait_for_key(fig, valid_keys)
  % Pauses execution and waits synchronously until a key in valid_keys is pressed
  key = '';                                        % Default empty return key
  setappdata(fig, 'last_key', '');                 % Clear any leftover keypress in memory
  while ishandle(fig)                              % Keep looping as long as figure window remains open
    pause(0.05);                                   % Sleep for 50 ms to prevent high CPU utilization
    k = getappdata(fig, 'last_key');               % Poll the last key pressed
    if any(strcmp(k, valid_keys))                  % If pressed key matches valid candidates
      key = k;                                     % Return the detected key
      return;                                      % Exit wait loop immediately
    endif
  endwhile
endfunction

function r = is_held(held, names)
  % Returns 1.0 if any key specified in 'names' is currently held down, else 0.0
  r = double(any(ismember(held, names)));          % Logical membership converted to double scalar
endfunction

function themes = get_level_themes()
  % Defines visual attributes, color schemes, and enemy stats for each realm
  themes = {};                                     % Container cell array for realm definitions

  % --- Realm 1: Infernal Crypt (Blood-red brick walls, crimson demons) ---
  themes{1}.name          = 'Infernal Crypt';      % Realm name
  themes{1}.wall_col      = [0.58, 0.16, 0.12];    % Wall RGB color: Dark reddish brown
  themes{1}.ceil_col      = [0.08, 0.03, 0.03];    % Ceiling RGB color: Pitch dark red
  themes{1}.floor_col     = [0.22, 0.14, 0.12];    % Floor RGB color: Dried blood stone
  themes{1}.demon_body    = [0.95, 0.15, 0.15];    % Demon sprite body RGB: Deep crimson
  themes{1}.demon_eye     = [1.00, 0.90, 0.10];    % Demon eye RGB: Glowing yellow/amber
  themes{1}.demon_hp      = 3;                     % Hits required to eliminate each demon
  themes{1}.demon_speed   = 1.4;                   % Pursuit speed (units per second)
  themes{1}.ammo_loot     = 4;                     % Ammo recovered per demon kill
  themes{1}.n_demons      = 6;                     % Total demons spawned in realm

  % --- Realm 2: Toxic Sewers (Moss green walls, acid ghouls) ---
  themes{2}.name          = 'Toxic Sewers';        % Realm name
  themes{2}.wall_col      = [0.12, 0.42, 0.22];    % Wall RGB color: Dark moss green
  themes{2}.ceil_col      = [0.02, 0.07, 0.03];    % Ceiling RGB color: Deep murky black-green
  themes{2}.floor_col     = [0.10, 0.22, 0.12];    % Floor RGB color: Slime-coated stone
  themes{2}.demon_body    = [0.20, 0.95, 0.30];    % Demon sprite body RGB: Toxic neon green
  themes{2}.demon_eye     = [1.00, 0.20, 0.85];    % Demon eye RGB: Piercing magenta
  themes{2}.demon_hp      = 3;                     % Hits required to eliminate each demon
  themes{2}.demon_speed   = 1.5;                   % Pursuit speed (units per second)
  themes{2}.ammo_loot     = 4;                     % Ammo recovered per demon kill
  themes{2}.n_demons      = 7;                     % Total demons spawned in realm

  % --- Realm 3: Frozen Abyss (Glacial blue walls, frost wraiths) ---
  themes{3}.name          = 'Frozen Abyss';        % Realm name
  themes{3}.wall_col      = [0.15, 0.30, 0.60];    % Wall RGB color: Glacial cobalt blue
  themes{3}.ceil_col      = [0.02, 0.04, 0.10];    % Ceiling RGB color: Midnight frozen abyss
  themes{3}.floor_col     = [0.12, 0.18, 0.30];    % Floor RGB color: Packed permafrost
  themes{3}.demon_body    = [0.35, 0.85, 1.00];    % Demon sprite body RGB: Spectral ice cyan
  themes{3}.demon_eye     = [1.00, 1.00, 1.00];    % Demon eye RGB: Pure white glare
  themes{3}.demon_hp      = 4;                     % Hits required to eliminate each demon
  themes{3}.demon_speed   = 1.5;                   % Pursuit speed (units per second)
  themes{3}.ammo_loot     = 5;                     % Ammo recovered per demon kill
  themes{3}.n_demons      = 7;                     % Total demons spawned in realm

  % --- Realm 4: Void Sanctuary (Amethyst walls, void stalkers) ---
  themes{4}.name          = 'Void Sanctuary';      % Realm name
  themes{4}.wall_col      = [0.38, 0.12, 0.50];    % Wall RGB color: Deep obsidian amethyst
  themes{4}.ceil_col      = [0.05, 0.02, 0.07];    % Ceiling RGB color: Cosmic void black
  themes{4}.floor_col     = [0.18, 0.10, 0.22];    % Floor RGB color: Dark violet stone
  themes{4}.demon_body    = [0.85, 0.25, 0.95];    % Demon sprite body RGB: Electric violet
  themes{4}.demon_eye     = [0.20, 1.00, 0.90];    % Demon eye RGB: Radiant turquoise
  themes{4}.demon_hp      = 4;                     % Hits required to eliminate each demon
  themes{4}.demon_speed   = 1.6;                   % Pursuit speed (units per second)
  themes{4}.ammo_loot     = 5;                     % Ammo recovered per demon kill
  themes{4}.n_demons      = 8;                     % Total demons spawned in realm
endfunction

function map = generate_random_maze(nr, nc)
  % Procedurally carves a solvable random labyrinth using Randomized DFS (Backtracker)
  map = ones(nr, nc);                              % Initialize entire grid as solid walls (value 1)

  start_r = 2;                                     % Starting row coordinate for the maze carving
  start_c = 2;                                     % Starting column coordinate for the maze carving
  map(start_r, start_c) = 0;                       % Carve initial open cell (value 0)

  stack_r = [start_r];                             % Stack tracking row history for recursive backtrack
  stack_c = [start_c];                             % Stack tracking col history for recursive backtrack

  while ~isempty(stack_r)                          % Repeat until every reachable cell has been explored
    cr = stack_r(end);                             % Peek current top row on stack
    cc = stack_c(end);                             % Peek current top column on stack

    dr = [-2, 2,  0, 0];                           % Row offsets to unvisited neighbors (2 steps away)
    dc = [ 0, 0, -2, 2];                           % Col offsets to unvisited neighbors (2 steps away)
    valid = [];                                    % List of valid candidate directions from current cell
    for i = 1:4                                    % Check each of the 4 cardinal directions (N, S, W, E)
      nr_pos = cr + dr(i);                         % Candidate neighbor row coordinate
      nc_pos = cc + dc(i);                         % Candidate neighbor column coordinate
      if nr_pos >= 2 && nr_pos <= nr-1 && nc_pos >= 2 && nc_pos <= nc-1
        if map(nr_pos, nc_pos) == 1                % Neighbor is still an uncarved solid wall
          valid(end+1) = i;                        % Store direction index as an eligible move
        endif
      endif
    endfor

    if ~isempty(valid)                             % If at least one unvisited neighbor exists
      chosen = valid(randi(numel(valid)));         % Select one candidate direction uniformly at random
      wr = cr + dr(chosen) / 2;                    % Row coordinate of the wall between current and neighbor
      wc = cc + dc(chosen) / 2;                    % Col coordinate of the wall between current and neighbor
      next_r = cr + dr(chosen);                    % Row coordinate of destination cell
      next_c = cc + dc(chosen);                    % Col coordinate of destination cell

      map(wr, wc) = 0;                             % Knock down the intermediary wall to create corridor
      map(next_r, next_c) = 0;                     % Carve open the destination cell

      stack_r(end+1) = next_r;                     % Push destination row onto the traversal stack
      stack_c(end+1) = next_c;                     % Push destination column onto the traversal stack
    else
      stack_r(end) = [];                           % Dead end reached: backtrack row stack
      stack_c(end) = [];                           % Dead end reached: backtrack column stack
    endif
  endwhile

  % Carve a few secondary openings to create loops and prevent tedious dead ends
  [wr, wc] = find(map(2:nr-1, 2:nc-1) == 1);       % Find remaining internal walls
  wr = wr + 1; wc = wc + 1;                        % Offset indices back to absolute matrix coordinates
  if numel(wr) > 5                                 % If sufficient candidate walls exist
    p = randperm(numel(wr), min(4, numel(wr)));    % Pick up to 4 wall positions at random
    for i = p                                      % Loop through selected walls
      map(wr(i), wc(i)) = 0;                       % Convert wall to corridor to introduce loop routes
    endfor
  endif

  % Guarantee player start area is spacious and unobstructed
  map(2, 2) = 0;                                   % Ensure starting tile is open
  map(2, 3) = 0;                                   % Ensure neighboring tile is open for initial movement
  map(nr-1, nc-1) = 0;                             % Ensure passage leading to exit is clear
  map(nr-1, nc)   = 2;                             % Place green portal exit on outer perimeter wall (value 2)
endfunction

function ok = can_walk(map, x, y, margin)
  % Tests if a bounding box of half-width 'margin' around (x, y) collides with walls
  [nr, nc] = size(map);                            % Dimensions of map matrix
  xs = [x - margin, x + margin, x - margin, x + margin]; % 4 corner X coordinates of player bounding box
  ys = [y - margin, y - margin, y + margin, y + margin]; % 4 corner Y coordinates of player bounding box
  ci = floor(xs) + 1;                              % Convert continuous X coordinates to 1-based matrix col
  ri = floor(ys) + 1;                              % Convert continuous Y coordinates to 1-based matrix row
  if any(ci < 1 | ci > nc | ri < 1 | ri > nr)      % Check if any corner is outside maze boundaries
    ok = false;                                    % Out-of-bounds position is illegal
    return;                                        % Exit function
  endif
  ok = all(map(sub2ind([nr nc], ri, ci)) == 0);    % True only if all 4 corners lie strictly on free tiles (0)
endfunction

function d = wall_distance(map, px, py, angle)
  % Casts a single ray forward from (px, py) along 'angle' to find distance to first wall
  [nr, nc] = size(map);                            % Dimensions of map matrix
  d = 14;                                          % Default maximum render distance
  for t = 0.04:0.04:14                             % Step through ray in increments of 0.04 units
    ci = floor(px + t * cos(angle)) + 1;           % Current matrix column along the ray
    ri = floor(py + t * sin(angle)) + 1;           % Current matrix row along the ray
    if ci < 1 || ci > nc || ri < 1 || ri > nr || map(ri, ci) > 0 % Check bounds or wall intersection (> 0)
      d = t;                                       % Distance at which ray struck wall or boundary
      return;                                      % Return distance immediately
    endif
  endfor
endfunction

function img = render_frame(map, px, py, angle, ex, ey, img_w, img_h, fov, cfg)
  % Renders entire first-person pseudo-3D scene (walls, sprites, radar minimap)
  [nr, nc] = size(map);                            % Get maze grid dimensions
  step    = 0.04;                                  % Step length along raycasting distance test
  max_d   = 14;                                    % Maximum raycast visibility distance
  offsets = linspace(-fov/2, fov/2, img_w);        % Angular offset for each screen column
  rays    = angle + offsets;                       % Absolute world angle for every screen column
  D = (step:step:max_d)';                          % Column vector of tested distances
  X = px + D * cos(rays);                          % Matrix of tested world X coordinates (distances x rays)
  Y = py + D * sin(rays);                          % Matrix of tested world Y coordinates (distances x rays)
  ci = min(max(floor(X) + 1, 1), nc);              % Clamped matrix column indices along rays
  ri = min(max(floor(Y) + 1, 1), nr);              % Clamped matrix row indices along rays
  cells = map(sub2ind([nr nc], ri, ci));           % Map values sampled along every ray step
  [anyhit, idx] = max(cells > 0, [], 1);           % Index of first non-zero cell hit along each column ray
  idx(~anyhit) = numel(D);                         % If ray hits nothing, clamp index to maximum distance
  lin = idx + (0:img_w-1) * numel(D);              % Convert 2D hit index to linear index in cells matrix
  wall_dist = D(idx)';                             % 1 x img_w array containing distance to wall for each column
  wall_type = cells(lin);                          % Wall type hit: 1 = regular wall, 2 = green exit portal
  wall_type(~anyhit) = 1;                          % Default miss type to regular wall
  xh = X(lin);                                     % World X intersection coordinates at wall surface
  yh = Y(lin);                                     % World Y intersection coordinates at wall surface

  % Wall shading and vertical faux-brick texture striping
  fx = min(mod(xh, 1), 1 - mod(xh, 1));            % Distance to nearest integer boundary along X
  fy = min(mod(yh, 1), 1 - mod(yh, 1));            % Distance to nearest integer boundary along Y
  face_x = fx < fy;                                % Determine whether wall face is North/South or East/West
  u = mod(face_x .* yh + (~face_x) .* xh, 1);      % Texture horizontal coordinate along wall face
  stripe = u < 0.06;                               % Faux-brick mortar line mask (dark vertical stripe)
  shade = (1 ./ (1 + 0.15 * wall_dist)) .* (0.75 + 0.25 * face_x) .* (1 - 0.4 * stripe); % Light attenuation
  base_wall = cfg.wall_col;                        % Realm-specific base wall color
  base_exit = [0.10, 0.95, 0.25];                  % Bright green color for the exit portal
  wall_h = img_h ./ max(wall_dist .* cos(offsets), 0.1); % Projected on-screen pixel height (fish-eye corrected)
  R = (1:img_h)';                                  % Column vector of screen row indices (1 to img_h)
  mask = abs(R - (img_h + 1)/2) <= wall_h / 2;     % Boolean mask: true where a wall column covers screen pixels

  img = zeros(img_h, img_w, 3);                    % Initialize final RGB frame buffer
  ceil_c  = cfg.ceil_col;                          % Ceiling color from realm config
  floor_c = cfg.floor_col;                         % Floor color from realm config
  for ch = 1:3                                     % Compute RGB channels individually
    bg = (R <= img_h/2) * ceil_c(ch) + (R > img_h/2) .* floor_c(ch) .* (0.3 + 0.7 * (R - img_h/2) / (img_h/2));
    wall_col = ((wall_type == 1) * base_wall(ch) + (wall_type == 2) * base_exit(ch)) .* shade;
    img(:, :, ch) = bg .* (~mask) + mask .* wall_col; % Composite background (sky/floor) and textured walls
  endfor

  % Billboard sprites (creatures), sorted and rendered far-to-near
  if ~isempty(ex)                                  % Check if there are active demons in the level
    dx = ex - px;                                  % Relative X displacement from player to demons
    dy = ey - py;                                  % Relative Y displacement from player to demons
    dist = hypot(dx, dy);                          % Euclidean distance to each demon
    rel = mod(atan2(dy, dx) - angle + pi, 2*pi) - pi; % Relative angle within player view frustum
    [~, order] = sort(dist, 'descend');            % Sort demon indices from farthest to nearest (Painter's Algo)
    for k = order(:)'                              % Render each demon in sorted order
      if abs(rel(k)) > fov/2 + 0.4 || dist(k) < 0.2% Skip if demon is outside FOV or clipping camera
        continue;                                  % Skip to next demon
      endif
      sprite_h = img_h * 0.7 / max(dist(k) * cos(rel(k)), 0.1); % Screen height of demon sprite
      sprite_w = sprite_h * 0.5;                   % Screen width of demon sprite (aspect ratio 1:2)
      center_col = (rel(k) / (fov/2)) * (img_w/2) + (img_w + 1)/2; % Horizontal center column on screen
      top_row = (img_h + 1)/2 - sprite_h/2;        % Top screen row of demon sprite
      cols = max(1, round(center_col - sprite_w/2)):min(img_w, round(center_col + sprite_w/2)); % Screen column range
      rows = max(1, round(top_row)):min(img_h, round(top_row + sprite_h)); % Screen row range
      eye_rows = max(1, round(top_row + 0.25 * sprite_h)):min(img_h, round(top_row + 0.25 * sprite_h) + 1); % Eye row band
      s = 1 / (1 + 0.15 * dist(k));                % Distance dimming factor for sprite
      body_c = cfg.demon_body;                     % Realm-specific demon body color
      eye_c  = cfg.demon_eye;                      % Realm-specific demon glowing eye color
      for c = cols                                 % Iterate over each horizontal column of the sprite
        if dist(k) < wall_dist(c) && ~isempty(rows)% Perform Z-buffer depth test against wall distance
          img(rows, c, 1) = body_c(1) * s;         % Write red channel of demon body
          img(rows, c, 2) = body_c(2) * s;         % Write green channel of demon body
          img(rows, c, 3) = body_c(3) * s;         % Write blue channel of demon body
          if abs(abs(c - center_col) - 0.2 * sprite_w) < max(0.8, 0.07 * sprite_w) % Eye horizontal placement
            img(eye_rows, c, 1) = eye_c(1);        % Write red channel of demon eye
            img(eye_rows, c, 2) = eye_c(2);        % Write green channel of demon eye
            img(eye_rows, c, 3) = eye_c(3);        % Write blue channel of demon eye
          endif
        endif
      endfor
    endfor
  endif

  % Tactical radar minimap rendered in top-left corner
  sc = 2;                                          % Scale factor: 2 pixels per maze grid cell
  wallm = kron(double(map == 1), ones(sc));        % 2x scaled boolean mask of maze walls
  exitm = kron(double(map == 2), ones(sc));        % 2x scaled boolean mask of portal exit
  mm = zeros(nr * sc, nc * sc, 3);                 % Initialize minimap RGB sub-image buffer
  mm(:, :, 1) = cfg.wall_col(1) * 0.7 * wallm;     % Minimap red channel: darkened wall color
  mm(:, :, 2) = cfg.wall_col(2) * 0.7 * wallm + 0.9 * exitm; % Minimap green channel: walls + bright exit
  mm(:, :, 3) = cfg.wall_col(3) * 0.7 * wallm;     % Minimap blue channel: darkened wall color
  for k = 1:numel(ex)                              % Paint blip for every living demon on radar
    r = min(max(floor(ey(k) * sc) + 1, 1), nr * sc); % Clamped radar row coordinate
    c = min(max(floor(ex(k) * sc) + 1, 1), nc * sc); % Clamped radar col coordinate
    mm(r, c, :) = reshape(cfg.demon_body, 1, 1, 3);% Draw demon blip with realm monster color
  endfor
  r = min(max(floor(py * sc) + 1, 1), nr * sc);    % Player radar row coordinate
  c = min(max(floor(px * sc) + 1, 1), nc * sc);    % Player radar column coordinate
  mm(r, c, :) = reshape([1 1 1], 1, 1, 3);         % Draw player blip in pure white
  img(1:nr*sc, 1:nc*sc, :) = mm;                   % Overlay radar minimap onto main viewport buffer
endfunction

function save_result(filename, kills, outcome, seconds, levels_cleared)
  % Appends match results to persistent text log file
  fid = fopen(filename, 'a');                      % Open file in append mode ('a')
  fprintf(fid, '%s | cleared = %d/4 | kills = %d | %s | %.1f s\n', ...
          datestr(now, 'yyyy-mm-dd HH:MM:SS'), levels_cleared, kills, outcome, seconds); % Format record entry
  fclose(fid);                                     % Close file handle
endfunction

% ------------------------- SETUP -----------------------------------------
clear; clc; close all;                             % Clear workspace, console window, and active figures

all_themes     = get_level_themes();               % Load realm parameters and monster profiles
img_w          = 120;                              % Viewport width in pixels (raycasting resolution)
img_h          = 72;                               % Viewport height in pixels
fov            = 1.05;                             % Field of view in radians (~60 degrees)
move_speed     = 2.6;                              % Marine movement speed (maze units / second)
turn_speed     = 2.2;                              % Camera turn angular speed (radians / second)
demon_wake     = 6.0;                              % Demon activation distance threshold (units)
start_health   = 100;                              % Starting player health points
start_ammo     = 18;                               % Starting player ammunition
results_file   = 'doom_fps_results.txt';           % Destination filename for match logs

% Create graphics figure and display axes
fig = figure('Name', 'DOOM FPS MINI - Hellish Dimension Campaign', 'NumberTitle', 'off', ...
             'Color', [0.08 0.02 0.02], 'KeyPressFcn', @key_press, 'KeyReleaseFcn', @key_release);
ax = axes('Parent', fig, 'Position', [0.05 0.05 0.90 0.82], ...
          'XTick', [], 'YTick', [], 'Box', 'on');   % Hide axes ticks for clean viewport display
h_img = image(ax, zeros(img_h, img_w, 3));         % Initialize image handle with blank canvas
axis(ax, 'image');                                 % Maintain pixel aspect ratio
hold(ax, 'on');                                    % Allow subsequent plotting of crosshair overlay
plot(ax, (img_w + 1)/2, (img_h + 1)/2, '+', 'MarkerSize', 14, 'Color', 'w'); % Crosshair at center

% ------------------------- ACROSS CAMPAIGNS LOOP -------------------------
play_again = true;                                 % Flag to allow replay after campaign ends
while play_again && ishandle(fig)                  % Outer loop: runs across full playthrough attempts

  health         = start_health;                   % Reset health to starting value
  ammo           = start_ammo;                     % Reset ammo to starting value
  kills          = 0;                              % Reset kill tally
  levels_cleared = 0;                              % Reset campaign realm progression counter
  required_wins  = 4;                              % Total levels required to earn trophy
  campaign_won   = false;                          % Victory flag
  campaign_timer = tic;                            % Start campaign stopwatch

  theme_idx = randi(numel(all_themes));            % Pick random initial realm theme

  % ---- Title Screen (Credits & Metadata) ----
  dummy_cfg = all_themes{theme_idx};               % Use selected theme for title screen preview
  preview_map = generate_random_maze(15, 15);      % Generate random background maze for title
  set(h_img, 'CData', render_frame(preview_map, 1.5, 1.5, 0, [], [], img_w, img_h, fov, dummy_cfg)); % Render preview
  title(ax, 'DOOM FPS MINI - v3', 'Color', 'y');   % Set figure title
  title_text = text(ax, (img_w + 1)/2, (img_h + 1)/2, { ...
                '=====================================', ...
                '        DOOM FPS MINI (v3)           ', ...
                '=====================================', ...
                'Authors : Camil & Bela', ...
                'Role    : Co-concept Designers', ...
                'Date    : 01/10/2026 (dd/mm/yyyy)', ...
                'Engine  : GNU Octave (Latest 9.x)', ...
                'AI Tools: Claude & Gemini', ...
                'Visuals : 100% Original Procedural Graphics', ...
                '=====================================', ...
                '', ...
                'Press SPACE to Continue' ...
               }, ...
               'HorizontalAlignment', 'center', 'Color', 'y', 'FontSize', 9, ...
               'FontName', 'monospace', 'BackgroundColor', 'k'); % Centered monospace credit card
  key = wait_for_key(fig, {'space', 'q', 'x', 'escape'}); % Wait for player confirmation or exit
  if ishandle(title_text), delete(title_text); endif % Clear title card from axes
  if isempty(key) || any(strcmp(key, {'q', 'x', 'escape'})) % If window closed or quit key pressed
    break;                                         % Terminate game
  endif

  % ---- Mission Briefing & Explanation Screen ----
  title(ax, 'MISSION: ESCAPE PLANET BEACHASOP', 'Color', 'y'); % Set briefing banner
  rules = text(ax, (img_w + 1)/2, (img_h + 1)/2, {'MISSION BRIEFING', ...
                'Stranded in a hellish dimension on Planet Beachasop!', ...
                'Escape 4 procedural mazes by reaching the GREEN PORTALS.', ...
                'Demons require 3-4 hits and drop +4 to +5 ammunition.', '', ...
                'W/S: Walk   A/D: Strafe   Left/Right: Turn   Space: Shoot', '', ...
                'Press SPACE to Begin Your Escape'}, ...
               'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 10, ...
               'BackgroundColor', 'k');            % Centered briefing overlay
  key = wait_for_key(fig, {'space', 'q', 'x', 'escape'}); % Wait for player input
  if ishandle(rules), delete(rules); endif         % Delete briefing card
  if isempty(key) || any(strcmp(key, {'q', 'x', 'escape'})) % Check if user quit
    break;                                         % Terminate game
  endif

  % ---- Campaign Progression Loop (Levels 1 to 4) ----
  while levels_cleared < required_wins && ishandle(fig) % Loop until 4 levels won or player dies
    cfg = all_themes{theme_idx};                   % Retrieve config for current realm

    map = generate_random_maze(15, 15);            % Procedurally generate brand-new solvable 15x15 maze
    [exit_row, exit_col] = find(map == 2);         % Locate green portal cell coordinates in grid
    exit_x = exit_col - 0.5;                       % Center world X coordinate of portal
    exit_y = exit_row - 0.5;                       % Center world Y coordinate of portal

    player_x     = 1.5;                            % Initial player X coordinate in maze
    player_y     = 1.5;                            % Initial player Y coordinate in maze
    player_angle = 0;                              % Initial player view angle (facing east)
    flash_timer  = 0;                              % Muzzle flash countdown counter

    % Spawn demon enemies on open cells sufficiently far from start
    [free_r, free_c] = find(map == 0);             % Find all open corridor cells
    far_enough = hypot(free_c - 0.5 - player_x, free_r - 0.5 - player_y) > 5; % Keep safe distance from start
    free_r = free_r(far_enough);                   % Filter rows of eligible spawn tiles
    free_c = free_c(far_enough);                   % Filter columns of eligible spawn tiles
    pick = randperm(numel(free_r), min(cfg.n_demons, numel(free_r))); % Select spawn cells at random
    demon_x  = free_c(pick)' - 0.5;                % Center world X coordinates of spawned demons
    demon_y  = free_r(pick)' - 0.5;                % Center world Y coordinates of spawned demons
    demon_hp = repmat(cfg.demon_hp, 1, numel(demon_x)); % Initialize health points vector for demons

    setappdata(fig, 'last_key', '');               % Clear residual key presses
    setappdata(fig, 'held', {});                   % Clear held key registry

    stage_running = true;                          % Flag indicating active realm gameplay
    stage_outcome = 'stopped';                     % Default stage outcome
    frame_clock = tic;                             % Start delta-time clock for physics calculations

    % ---- Main Game Frame Loop ----
    while stage_running && ishandle(fig)           % Per-frame game loop
      held = getappdata(fig, 'held');              % Poll currently held movement keys
      key  = getappdata(fig, 'last_key');          % Poll one-shot trigger key (shoot/quit)
      setappdata(fig, 'last_key', '');             % Reset one-shot key buffer
      dt = min(toc(frame_clock), 0.1);             % Compute delta time capped at 100 ms
      frame_clock = tic;                           % Reset delta-time clock for next frame

      % Calculate desired movement deltas
      move_fwd  = move_speed * dt * (is_held(held, {'w'}) - is_held(held, {'s'})); % Forward/backward speed
      move_side = move_speed * dt * (is_held(held, {'d'}) - is_held(held, {'a'})); % Strafe right/left speed
      player_angle = player_angle + turn_speed * dt * ...
                     (is_held(held, {'rightarrow', 'right', 'e'}) - is_held(held, {'leftarrow', 'left', 'q'})); % Yaw

      % Shooting & hitscan combat logic
      if strcmp(key, 'space') && ammo > 0          % Space pressed with available ammunition
        ammo = ammo - 1;                           % Deduct 1 bullet
        flash_timer = 2;                           % Set muzzle flash illumination for 2 frames
        dx = demon_x - player_x;                   % Relative X vector to each demon
        dy = demon_y - player_y;                   % Relative Y vector to each demon
        dist = hypot(dx, dy);                      % Distance to each demon
        rel = mod(atan2(dy, dx) - player_angle + pi, 2*pi) - pi; % Relative angle to crosshair
        visible = dist < wall_distance(map, player_x, player_y, player_angle); % Check line-of-sight obstruction
        candidates = find(abs(rel) < pi/2 & abs(sin(rel)) .* dist < 0.45 & visible); % Find target near crosshair
        if ~isempty(candidates)                    % If at least one demon is targeted
          [~, nearest] = min(dist(candidates));    % Find closest demon along reticle line
          victim = candidates(nearest);            % Select target demon index
          demon_hp(victim) = demon_hp(victim) - 1; % Inflict 1 damage point
          if demon_hp(victim) <= 0                 % If demon health reaches zero
            demon_x(victim)  = [];                 % Remove X position from active demon list
            demon_y(victim)  = [];                 % Remove Y position from active demon list
            demon_hp(victim) = [];                 % Remove HP record from active demon list
            kills = kills + 1;                     % Increment total kill count
            ammo  = ammo + cfg.ammo_loot;          % Award bonus ammunition drop
          endif
        endif
      elseif any(strcmp(key, {'escape', 'x'}))     % Escape or X pressed to abort match
        stage_outcome = 'stopped';                 % Flag stage as stopped
        stage_running = false;                     % Break out of inner loop
        break;                                     % Exit frame loop
      endif

      % Player movement with axis-separated collision resolution (wall sliding)
      new_x = player_x + move_fwd * cos(player_angle) - move_side * sin(player_angle); % New X coordinate
      new_y = player_y + move_fwd * sin(player_angle) + move_side * cos(player_angle); % New Y coordinate
      if can_walk(map, new_x, player_y, 0.2), player_x = new_x; endif % Update X if unobstructed
      if can_walk(map, player_x, new_y, 0.2), player_y = new_y; endif % Update Y if unobstructed

      % Demon pursuit AI (demons move toward marine if within detection radius)
      for k = 1:numel(demon_x)                     % Iterate over each active demon
        dist_k = hypot(player_x - demon_x(k), player_y - demon_y(k)); % Distance from demon k to player
        if dist_k < demon_wake                     % If marine is within wake detection range
          new_dx = demon_x(k) + cfg.demon_speed * dt * (player_x - demon_x(k)) / dist_k; % Move along X axis
          new_dy = demon_y(k) + cfg.demon_speed * dt * (player_y - demon_y(k)) / dist_k; % Move along Y axis
          if can_walk(map, new_dx, demon_y(k), 0.25), demon_x(k) = new_dx; endif % Slide along X if open
          if can_walk(map, demon_x(k), new_dy, 0.25), demon_y(k) = new_dy; endif % Slide along Y if open
        endif
      endfor

      % Contact bites from demons
      bites = hypot(player_x - demon_x, player_y - demon_y) < 0.7; % Detect demons touching marine
      if any(bites)                                % If at least one demon contacted player
        health = health - 10 * sum(bites);         % Deduct 10 health per attacking demon
        demon_x(bites)  = [];                      % Explode contacting demon (remove X)
        demon_y(bites)  = [];                      % Explode contacting demon (remove Y)
        demon_hp(bites) = [];                      % Explode contacting demon (remove HP)
      endif

      % Render current 3D frame and HUD
      frame = render_frame(map, player_x, player_y, player_angle, demon_x, demon_y, img_w, img_h, fov, cfg);
      if flash_timer > 0                           % Apply muzzle flash visual effect
        frame = min(frame + 0.25, 1);              % Brighten viewport pixels
        flash_timer = flash_timer - 1;             % Decrement flash timer
      endif
      set(h_img, 'CData', frame);                  % Push new pixel data into graphics axes
      title(ax, sprintf('[Realm %d/4: %s]  HP: %d  Ammo: %d  Kills: %d  Demons: %d', ...
                        levels_cleared + 1, cfg.name, health, ammo, kills, numel(demon_x)), 'Color', 'y'); % Update HUD
      drawnow;                                     % Force graphics pipeline flush
      pause(0.01);                                 % Short pause for OS event queue processing

      % Evaluate stage progression conditions
      if hypot(player_x - exit_x, player_y - exit_y) < 1.3 % Marine reached green portal
        stage_outcome = 'stage_win';               % Mark realm as successfully completed
        stage_running = false;                     % Exit frame loop
      elseif health <= 0                           % Player health reached zero
        stage_outcome = 'lose';                    % Mark match as defeated
        stage_running = false;                     % Exit frame loop
      endif
    endwhile

    if ~ishandle(fig) || strcmp(stage_outcome, 'stopped') % If figure destroyed or game manually halted
      break;                                       % Break out of campaign loop
    endif

    if strcmp(stage_outcome, 'stage_win')          % If realm was conquered
      levels_cleared = levels_cleared + 1;         % Increment conquered realms counter
      health = min(100, health + 25);              % Reward player with +25 health bonus
      if levels_cleared < required_wins            % If more levels remain in campaign
        theme_idx = mod(theme_idx, numel(all_themes)) + 1; % Cycle to next realm visual theme
        inter_text = text(ax, (img_w + 1)/2, (img_h + 1)/2, ...
                          {sprintf('REALM %d CONQUERED!', levels_cleared), ...
                           '+25 Health Restored!', '', ...
                           sprintf('Next Dimension: %s', all_themes{theme_idx}.name), '', ...
                           'Press SPACE to Enter the Next Rift'}, ...
                          'HorizontalAlignment', 'center', 'Color', 'g', 'FontSize', 12, ...
                          'BackgroundColor', 'k'); % Stage transition card
        k = wait_for_key(fig, {'space', 'q', 'escape'}); % Wait for confirmation
        if ishandle(inter_text), delete(inter_text); endif % Clear transition card
        if any(strcmp(k, {'q', 'escape'}))         % Check if user aborted
          break;                                   % Terminate campaign
        endif
      else
        campaign_won = true;                       % Set full campaign victory flag
      endif
    elseif strcmp(stage_outcome, 'lose')           % If player died in battle
      break;                                       % Terminate campaign
    endif
  endwhile

  if ~ishandle(fig), break; endif                  % Exit if figure closed

  % ---- Campaign Conclusion / Trophy & Results Screen ----
  total_seconds = toc(campaign_timer);             % Calculate total elapsed campaign time
  if campaign_won                                  % If player conquered all 4 realms
    save_result(results_file, kills, 'VICTORY', total_seconds, levels_cleared); % Log victory to file

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
                  'Press  R  to Replay  or  Q  to Quit'}; % Trophy ASCII art

    endtext = text(ax, (img_w + 1)/2, (img_h + 1)/2, trophy_msg, ...
                   'HorizontalAlignment', 'center', 'Color', [1 0.84 0], 'FontName', 'monospace', ...
                   'FontSize', 9, 'BackgroundColor', 'k'); % Display gold trophy screen
  else                                             % If player failed
    save_result(results_file, kills, 'DEFEAT', total_seconds, levels_cleared); % Log defeat to file
    endtext = text(ax, (img_w + 1)/2, (img_h + 1)/2, ...
                   {'M.I.A. IN THE HELLISH DIMENSION', ...
                    sprintf('Realms Escaped: %d / 4', levels_cleared), ...
                    sprintf('Kills: %d  |  Time: %.0f s', kills, total_seconds), '', ...
                    'Press  R  to Retry  or  Q  to Quit'}, ...
                   'HorizontalAlignment', 'center', 'Color', 'r', 'FontSize', 12, ...
                   'BackgroundColor', 'k');        % Display defeat screen
  endif

  key = wait_for_key(fig, {'r', 'q', 'escape'});   % Wait for replay or exit command
  if ishandle(endtext), delete(endtext); endif     % Clear end text card
  play_again = strcmp(key, 'r');                   % Set replay flag true if 'r' was pressed
endwhile

if ishandle(fig), close(fig); endif                % Close figure window upon full termination
disp('Mission concluded. Results recorded in doom_fps_results.txt'); % Print closing console message
