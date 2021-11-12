require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code

enum Modes:int
    Easy = 0
    Normal = 1
    Hard = 2

enum GameState:int
    Menu = 0
    Game = 1
    Lose = 2
    Win = 3

enum CellMark:int
    None = 0
    Flag = 1
    Unknown = 2

let

    MIN_WIDTH = 1280
    MIN_HEIGHT = 768

    BOMB_NONE = 0
    BOMB_HERE = 10

    //COLOR_FIELD_BG = 0xDDDDDD
    //COLOR_CELL_BORDER = 0xFFFFFF
    COLOR_FIELD_TEXT = 0x000000
    COLOR_MENU_BG = 0xFFFFFF

    TIME_AFTER_END = 5.0

struct CellState
    opened:bool = false
    mark:CellMark = CellMark None
    bomb:int = BOMB_NONE

struct Difficulty
    size: int2
    mines: int

struct Game
    mode:Modes = Modes Easy
    time:float = 0.0
    user_bomb_count:int = 0

struct Board
    pos:int2
    size:int2

struct MenuItem
    pos:int2
    size:int2
    image:Image
    mode_action:Modes

var
    RAND_SEED: int4
    field : array<CellState?>
    scr_w: int
    scr_h: int
    board:Board
    dif: Difficulty[3]
    game: Game = Game()
    menu: MenuItem[3]

    image_logo: Image
    image_cell_opened: Image
    image_cell_closed: Image
    image_cell_flaged: Image
    image_cell_bomb: Image
    image_cell_unknown: Image

    image_easy: Image
    image_normal: Image
    image_hard: Image

    sfx_bomb: PcmSound
    sfx_click: PcmSound
    sfx_win: PcmSound
    sfx_unflag: PcmSound
    sfx_flag: PcmSound

    draw_opened_field: bool = false
    cell_size:int
    state:GameState = GameState Menu
    wait_timer: float
    last_bomb:int2

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("DaMinesweeper")
    load_images()
    load_sounds()
    set_resolution(MIN_WIDTH, MIN_HEIGHT)

    scr_w = get_screen_width()
    scr_h = get_screen_height()

    init_menu()
    init_difficulty()

    randomize_seed(RAND_SEED)
    //RAND_SEED = int4(1)

def load_images()
    image_logo <- create_image("img_logo.png")
    image_cell_opened <- create_image("cell_opened.png")
    image_cell_closed <- create_image("cell_closed.png")
    image_cell_flaged <- create_image("cell_flaged.png")
    image_cell_unknown <- create_image("cell_unknown.png")
    image_cell_bomb <- create_image("cell_bomb.png")

    image_easy <- create_image("img_easy.png")
    image_normal <- create_image("img_normal.png")
    image_hard <- create_image("img_hard.png")
    //make_image_color_transparent(image_logo, get_pixel(image_logo, 0, 0))

def load_sounds()
    sfx_bomb <- create_sound("sfx_bomb.wav")
    sfx_click <- create_sound("sfx_click.wav")
    sfx_win <- create_sound("sfx_win.wav")
    sfx_unflag <- create_sound("sfx_unflag.wav")
    sfx_flag <- create_sound("sfx_flag.wav")

def init_menu()
    let delta_x = (scr_w / 3)
    let delta_x_offset = delta_x >> 1
    let pos_y = scr_h / 2

    menu[0].image <- image_easy
    menu[0].pos = int2(delta_x_offset - (menu[0].image.width>>1), scr_h>>1)
    menu[0].size = int2(menu[0].image.width,menu[0].image.height)
    menu[0].mode_action = Modes Easy

    menu[1].image <- image_normal
    menu[1].pos = int2(delta_x*2 -delta_x_offset - (menu[1].image.width>>1), scr_h>>1)
    menu[1].size = int2(menu[1].image.width,menu[1].image.height)
    menu[1].mode_action = Modes Normal

    menu[2].image <- image_hard
    menu[2].pos = int2(delta_x*3 -delta_x_offset - (menu[2].image.width>>1), scr_h>>1)
    menu[2].size = int2(menu[2].image.width,menu[2].image.height)
    menu[2].mode_action = Modes Hard

def init_difficulty
    dif[0].mines=10
    dif[0].size=int2(9,9)

    dif[1].mines=25
    dif[1].size=int2(16,16)

    dif[2].mines=60
    dif[2].size=int2(30,16)

def reset_game()
    wait_timer = 0.0
    field|>clear()
    game.time = 0.0
    game.user_bomb_count = 0
    last_bomb = int2(-1,-1)

def start_game(difficulty:Modes)
    reset_game()

    game.mode = difficulty

    cell_size = scr_h / (get_current_field_size().x + 2)

    board.pos.x = cell_size
    board.pos.y = cell_size

    board.size.x = cell_size * get_current_field_size().x
    board.size.y = cell_size * get_current_field_size().y

    generate_minefield(get_current_field_size().x, get_current_field_size().y, dif[int(difficulty)].mines, field)
    state = GameState Game

def get_current_field_size():int2
    return dif[int(game.mode)].size

def generate_minefield(w: int; h:int; count:int; var field:array<CellState?>)
    //clear and fill dynamic array, probably it has a better way
    for i in range(w*h)
        field|>push(new CellState)

    var mines = 0
    while mines!=count
        var x = random_int(RAND_SEED) % w
        var y = random_int(RAND_SEED) % h
        if get_cell_type(x,y) == BOMB_NONE
            set_cell_type(x,y, BOMB_HERE)

            mines++

            for i in range(-1,2)
                for j in range (-1,2)
                    if (i==0 && j==0)
                        continue
                    var x2 = x+i
                    var y2 = y+j
                    if (x2 < 0)
                        continue
                    if (y2 < 0)
                        continue
                    if (x2 > (w-1))
                        continue
                    if (y2 > (h-1))
                        continue

                    if get_cell_type(x2,y2)!=BOMB_HERE
                        set_cell_type(x2,y2,get_cell_type(x2,y2)+1)

// def render_field_bg
//     fill_rect(board.pos.x, board.pos.y, board.size.x,board.size.y, COLOR_FIELD_BG)
//     for x in range(0,get_current_field_size().x+1)
//         line(board.pos.x+cell_size*x, board.pos.y, board.pos.x+cell_size*x, board.pos.y+board.size.y,COLOR_CELL_BORDER)
//     for y in range(0,get_current_field_size().y+1)
//         line(board.pos.x, board.pos.y+cell_size*y, board.pos.x+board.size.x, board.pos.y+cell_size*y,COLOR_CELL_BORDER)
//     return

def render_menu
    fill_rect(0, 0, scr_w, scr_h, COLOR_MENU_BG)
    draw_image(image_logo,scr_w/2 - image_logo.width/2 ,0, 0xFFFFFF)

    for i in range(3)
        draw_image(menu[i].image,menu[i].pos.x,menu[i].pos.y,0xFFFFFF)

    return

// def render_cell(x:int;y:int;color:uint)
//     fill_rect(board.pos.x+x*cell_size+1,board.pos.y+y*cell_size+1,cell_size-1,cell_size-1,color)

def render_cell_image(image:Image;x:int;y:int;color:uint = 0xffffff)
    let scaled_size = int2(cell_size, cell_size)
    draw_image(image,board.pos.x+x*cell_size+1,board.pos.y+y*cell_size+1,color,scaled_size)

def render_flag(x:int;y:int)
    render_cell_image(image_cell_flaged, x ,y)
    //render_cell(x,y,COLOR_CELL_FLAG)

def render_unknown(x:int;y:int)
    render_cell_image(image_cell_unknown, x ,y)
    //render_cell(x,y,COLOR_CELL_UNKOWN)

def render_closed(x:int;y:int)
    render_cell_image(image_cell_closed, x ,y)
    //render_cell(x,y,COLOR_CELL_CLOSED)

def render_opened(x:int;y:int)
    render_cell_image(image_cell_opened, x ,y)

def render_bomb(x:int;y:int;color:uint=0xffffff)
    render_cell_image(image_cell_bomb, x ,y,color)
    //render_cell(x,y,0xFF0000)

def render_user_field
    var w = get_current_field_size().x
    var h = get_current_field_size().y
    for x in range(0,w)
        for y in range(0,h)
            if !is_cell_opened(x,y)
                render_closed(x,y)
                if get_cell_mark(x,y) == CellMark Flag
                    render_flag(x,y)
                elif get_cell_mark(x,y) == CellMark Unknown
                    render_unknown(x,y)
            else
                render_opened(x,y)
                if get_cell_type(x,y) != BOMB_NONE
                    let mines_around = get_cell_type(x,y)
                    let str = "{mines_around}"
                    set_font_name("sans")
                    set_font_size(cell_size)
                    var size = get_text_size(str)
                    text_out(board.pos.x+x*cell_size+int(size.x/2.0),board.pos.y+y*cell_size-int(size.y/2.0)+cell_size/3,str,COLOR_FIELD_TEXT)


def render_whole_field
    var w = get_current_field_size().x
    var h = get_current_field_size().y
    for x in range(0,w)
        for y in range(0,h)
            if get_cell_type(x,y) == BOMB_HERE
                var is_last = last_bomb.x!=-1 && last_bomb.x!=-1 && last_bomb.x == x && last_bomb.y == y
                render_bomb(x,y,is_last?0xFF0000:0xFFFFFF)
            elif get_cell_type(x,y) != BOMB_NONE
                render_opened(x,y)
                let mines_around = get_cell_type(x,y)
                let str = "{mines_around}"
                set_font_name("sans")
                set_font_size(cell_size)
                let size = get_text_size(str)
                text_out(board.pos.x+x*cell_size+int(size.x/2.0),board.pos.y+y*cell_size-int(size.y/2.0)+cell_size/3,str,COLOR_FIELD_TEXT)
            else
                render_opened(x,y)

def render_game_scores
    let font_height = 30
    set_font_name("sans")
    set_font_size(font_height)
    let seconds = int(game.time);
    let text_x = board.pos.x+board.size.x+cell_size
    text_out(text_x,cell_size,"Time: {seconds} secs",0xFFFFFF)
    let bombs = dif[int(game.mode)].mines
    text_out(text_x,font_height+cell_size,"Bomb: {bombs}",0xFFFFFF)
    text_out(text_x,font_height*2+cell_size,"Flags: {game.user_bomb_count}",0xFFFFFF)

def render_end_screen(win:bool)
    set_font_name("sans")
    set_font_size(40)
    let text = win ? "You WIN !" : "You LOSE !"
    let size = get_text_size(text)
    var x = scr_w / 2 - int(size.x / 2.0)
    var y = scr_h / 2 - int(size.y / 2.0)
    fill_rect(0, scr_h/2 - int(size.y),scr_w, int(size.y)*2, win ? 0x063606 : 0x4E0505)
    text_out(x,y,text,win ? 0xFFFFFF : 0x000000)

def get_cell_type(x:int; y:int):int
    return field[x * get_current_field_size().y + y].bomb

def set_cell_type(x:int; y:int; cell_type:int)
    field[x  *get_current_field_size().y + y].bomb = cell_type

def get_cell_mark(x:int; y:int):CellMark
    return field[x * get_current_field_size().y + y].mark

def set_cell_mark(x:int; y:int; cell_mark:CellMark)
    field[x * get_current_field_size().y + y].mark = cell_mark

def is_cell_opened(x:int; y:int)
    return field[x * get_current_field_size().y + y].opened

def set_cell_opened(x:int; y:int)
    field[x * get_current_field_size().y + y].opened = true

def is_mouse_outside_board(mouse_pos:float2):bool
    let x = int(mouse_pos.x)
    let y = int(mouse_pos.y)
    return x<board.pos.x || y<board.pos.y || x>=board.pos.x+board.size.x || y>=board.pos.y+board.size.y

def get_cell_xy_from_mouse(mouse_pos:float2):int2
    var x = (int(mouse_pos.x)-board.pos.x) / cell_size
    var y = (int(mouse_pos.y)-board.pos.y) / cell_size
    return int2(x,y)

def action_lose(x:int; y:int)
    sfx_bomb |> play_sound()
    set_cell_opened(x,y)
    last_bomb = int2(x,y)
    state = GameState Lose

def is_valid_for_open(x:int; y:int):bool

    if x<0 || y<0
        return false
    var w = get_current_field_size().x
    var h = get_current_field_size().y
    if x>w-1 || y>h-1
        return false

    if is_cell_opened(x,y)
        return false
    if get_cell_type(x,y) == BOMB_HERE
        return false

    return true

def check_game_win():bool
    var w = get_current_field_size().x
    var h = get_current_field_size().y
    var all_bomb_opened:bool = true
    var all_cells_opened:bool = true
    for x in range (0,w)
        for y in range (0,h)
            if (get_cell_type(x,y) == BOMB_HERE && get_cell_mark(x,y) == CellMark None)
                all_bomb_opened = false
                break
            if (get_cell_type(x,y) != BOMB_HERE && !is_cell_opened(x,y))
                all_cells_opened = false
                break

        if !all_bomb_opened || !all_cells_opened
            break
    return all_bomb_opened && all_cells_opened

def action_open_cell(x:int; y:int)

    if x<0 || y<0
        return
    var w = get_current_field_size().x
    var h = get_current_field_size().y

    if x>=w || y>=w
        return

    if is_cell_opened(x,y)
        return

    set_cell_opened(x,y)

    if get_cell_type(x,y) != BOMB_NONE
        return


    if is_valid_for_open(x+1,y-1)
        action_open_cell(x+1,y-1)//NW

    if is_valid_for_open(x,y-1)
        action_open_cell(x,y-1)//N

    if is_valid_for_open(x-1,y-1)
        action_open_cell(x-1,y-1)//NE

    if is_valid_for_open(x-1,y)
        action_open_cell(x-1,y)//E

    if is_valid_for_open(x+1,y)
        action_open_cell(x+1,y)//W

    if is_valid_for_open(x-1,y+1)
        action_open_cell(x-1,y+1)//SE

    if is_valid_for_open(x,y+1)
        action_open_cell(x,y+1)//S

    if is_valid_for_open(x+1,y+1)
        action_open_cell(x+1,y+1)//SW


//by right mouse - mark cell as MINE, or UNKOWN or reset
def mark_cell_and_process(xy:float2)
    if is_mouse_outside_board(xy)
        return
    var cell = get_cell_xy_from_mouse(xy)
    var cell_type = get_cell_type(cell.x,cell.y)

    if is_cell_opened(cell.x,cell.y)
        return

    var mark = get_cell_mark(cell.x,cell.y)
    if mark == CellMark None
        sfx_flag |> play_sound()
        set_cell_mark(cell.x,cell.y,CellMark Flag)
        game.user_bomb_count++
    elif mark == CellMark Flag
        sfx_unflag |> play_sound()
        set_cell_mark(cell.x,cell.y,CellMark Unknown)
        game.user_bomb_count--
    elif  mark == CellMark Unknown
        set_cell_mark(cell.x,cell.y,CellMark None)

def check_menu_items(xy:float2)
    let x = int(xy.x)
    let y = int(xy.y)
    for i in range(3)
        if x > menu[i].pos.x && y > menu[i].pos.y && x<menu[i].pos.x+menu[i].size.x && y<menu[i].pos.y+menu[i].size.y
            start_game(menu[i].mode_action)
            break

//clicking by left mouse - open cells, if it's not a mine
def check_hit_and_process(xy:float2)
    if is_mouse_outside_board(xy)
        return
    var cell = get_cell_xy_from_mouse(xy)
    var cell_type = get_cell_type(cell.x,cell.y)

    if cell_type == BOMB_HERE //if it's a mine - then explose it, the game over
        action_lose(cell.x,cell.y)
    else
        sfx_click |> play_sound()
        action_open_cell(cell.x,cell.y)

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if state == GameState Menu
        if get_mouse_button_down(MB_LEFT)
            check_menu_items(get_mouse_position())
        if get_key_press(VK_ESCAPE)
            schedule_quit_game()
    elif state == GameState Game
        if get_key_press(VK_ESCAPE)
            state = GameState Menu
            reset_game()
            return

        game.time+=dt

        //DO NOT CHEAT
        if get_key_press(VK_0)
            draw_opened_field = !draw_opened_field


        if get_mouse_button_down(MB_LEFT)
            check_hit_and_process(get_mouse_position())
        elif get_mouse_button_down(MB_RIGHT)
            mark_cell_and_process(get_mouse_position())
        if check_game_win()
            state = GameState Win
            sfx_win |> play_sound()
    else
        wait_timer+=dt
        if wait_timer > TIME_AFTER_END
            if get_key(VK_ESCAPE) || get_mouse_button_down(MB_LEFT)
                state = GameState Menu
                reset_game()

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    if state == GameState Menu
        render_menu()
    else
        //render_field_bg()
        if state == GameState Game
            if draw_opened_field
                render_whole_field()
            else
                render_user_field()
        else
            render_whole_field()

        render_game_scores()

        if (state == GameState Win || state == GameState Lose) && wait_timer > TIME_AFTER_END
            render_end_screen(state == GameState Win)

