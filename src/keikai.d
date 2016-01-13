import deimos.ncurses.curses;
import std.conv;
import std.string;
import std.format;
import std.algorithm.iteration, std.algorithm.comparison;
import std.string;
import std.array;
import core.thread;

interface Scorable {
public:
    double score();

    @property string description();
    @property string description(string);
}

interface GradeContainer {
public:
    Scorable[] members();
    bool select(in int index, ref GradeContainer);    
    bool parent(ref GradeContainer);
    string _headline();
}

interface InteractiveContainer {
public:
    void wpromptadd(WINDOW* win, int index);
    void wpromptdel(WINDOW* win, int index);
    void wpromptedit(WINDOW* win, int index);
}

template hasPoints(T){
    enum hasPoints = is(typeof({T obj; obj.points; obj.maxPoints;}()));
}

string entry(T : Scorable)(T s) {
    string label = s.description == "" ? "<Unnamed>" : s.description;

    static if(hasPoints!T) return format("%s [%.2f%% (%.0f/%.0f)]", label, s.score, s.points, s.maxPoints);
    else return format("%s [%.2f%%]", label, s.score);
}

string label(T : GradeContainer)(T gc) {
    return gc.description == "" ? "<Unnamed>" : gc.description;
}

string headline(T)(T obj) {
    return format(" %s ", obj._headline).center(COLS, '-');
}

template property(T, string name) {
    const string property = "@property public " ~ T.stringof ~ " " ~ name ~ "() { return this._" ~ name ~ "; }"
    ~ "@property public " ~ T.stringof ~ " " ~ name ~ "(" ~ T.stringof ~ " _" ~ name ~ ") { return (this._" ~ name ~ " = _" ~ name ~ "); }"
    ~ "private " ~ T.stringof ~ " _" ~ name ~ ";";
}

class Grade : Scorable {
public:
    double score() {
        return (points * 100) / maxPoints;
    }

    mixin(property!(double, "points"));
    mixin(property!(double, "maxPoints"));
    mixin(property!(string, "description"));

    this(double points, double maxPoints, string description) {
        this._points = points;
        this._maxPoints = maxPoints;
        this._description = description;
    }

    invariant {
        assert(_maxPoints > 0);
    }
}

class Category : Scorable, GradeContainer {
public:
    double points() {
        return grades.map!(x => x.points).sum(0.0);
    }

    double maxPoints() {
        return grades.map!(x => x.maxPoints).sum(0.0);
    }

    double score() {
        if(grades.length == 0) return 100;
        return (points * 100) / maxPoints;
    }

    Scorable[] members() {
        Scorable[] view;
        view.length = grades.length;
        foreach(i, g; grades) view[i] = g;
        return view;
    }

    bool select(in int index, ref GradeContainer down) {
        down = this;
        return true;
    }

    bool parent(ref GradeContainer up) {
        if(this.up) {
            up = this.up;
            return true;
        } else return false;
    }

    string _headline() {
        return format("%s grades", this.label);
    }

    mixin(property!(double, q{weight}));
    mixin(property!(string, q{description}));
    mixin(property!(Course, q{up}));

    this(double weight) {
        this._weight = weight;
    }

    void addGrade(Grade g) {
        grades ~= g;
    }
private:
    Grade[] grades;
}

class Course : Scorable, GradeContainer {
public:
    double score() {
        if(categories.length == 0) return 100;
        else return categories.map!(x => x.score * x.weight).sum(0.0);
    }

    double totalWeight() {
        return categories.map!(x => x.weight).sum(0.0);
    }

    Scorable[] members() {
        Scorable[] view;
        view.length = categories.length;
        foreach(i, c; categories) view[i] = c;
        return view;
    }

    bool select(in int index, ref GradeContainer down) {
        if(index < categories.length) {
            down = categories[index];

            if(down.members.length == 1) return down.select(0, down);

            return true;
        } else return false;
    }

    bool parent(ref GradeContainer up) {
        if(this.up) {
            up = this.up;
            return true;
        } else return false;
    }

    string _headline() {
        return this.label;
    }

    this(string description) {
        this.description = description;
    }

    void addCategory(Category c) {
        categories ~= c;
        c.up = this;
    }

    mixin(property!(string, q{description}));
    mixin(property!(Gradebook, q{up}));
private:
    Category[] categories;
}

class Gradebook : GradeContainer {
public:
    Scorable[] members() {
        Scorable[] view;
        view.length = courses.length;
        foreach(i, c; courses) view[i] = c;
        return view;
    }

    bool select(in int index, ref GradeContainer down) {
        if(index < courses.length) {
            down = courses[index];

            if(down.members.length == 1) return down.select(0, down);

            return true;
        } else return false;
    }

    bool parent(ref GradeContainer up) {
        up = this;
        return true;
    }

    string _headline() {
        return "All grades";
    }

    this() {};

    void addCourse(Course c) {
        courses ~= c;
        c.up = this;
    }

private:
    Course[] courses;
}

void wprintmenu(WINDOW* scr, string[] options, int highlighted) {
    werase(scr);
    wmove(scr, 0, 0);

    int x = 0, y = 0;

    foreach(i, option; options) {
        wmove(scr, y, x);
        
        if(i < 10) wprintw(scr, "%d: %s", (i + 1) % 10, option.toStringz);
        else wprintw(scr, "   %s", option.toStringz);

        if(highlighted == i)
            mvwchgat(scr, y, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);

        y++;
    }
}

string wgetnstring(WINDOW* scr, int n)
in {
    assert(n > 0);
} body {
    char[] buf;
    buf.length = n;

    wgetnstr(scr, buf.ptr, n);

    return to!string(buf.ptr);
}

string getnstring()(int n) {
    return wgetnstring(stdscr, n);
}

string promptString(WINDOW* scr, string prompt) {
    echo();
    curs_set(1);

    werase(scr);
    mvwchgat(scr, 0, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);
    wattron(scr, A_REVERSE);

    mvwprintw(scr, 0, FOOTER_OFFSET, "%s", prompt.toStringz);
    wrefresh(scr);
    string input = wgetnstring(scr, MAX_INPUT_LENGTH);

    noecho();
    curs_set(0);

    return input;
}

double promptDouble(WINDOW* scr, string prompt) {
    while(true) {
        try return to!double(promptString(scr, prompt));
        catch(ConvException e) {
            werase(scr);
            mvwprintw(scr, 0, FOOTER_OFFSET, "That doesn't seem to be a number.");
            wrefresh(scr);
            Thread.sleep(dur!"msecs"(ERROR_DISPLAY_DURATION_MS));
        }
    }
}

double promptDouble(WINDOW* scr, string prompt, double def) {
    while(true) {
        try {
            string input = promptString(scr, prompt);
            if(input == "") return def;
            else return to!double(input);
        } catch(ConvException e) {
            werase(scr);
            mvwprintw(scr, 0, FOOTER_OFFSET, "That doesn't seem to be a number.");
            wrefresh(scr);
            Thread.sleep(dur!"msecs"(ERROR_DISPLAY_DURATION_MS));
        }
    }
}

enum HEADER = "keikai 0.0.1";
enum MAX_INPUT_LENGTH = 80;
enum FOOTER_OFFSET = 2;
enum ERROR_DISPLAY_DURATION_MS = 1_250;

int main(string[] args) {
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, true);
    curs_set(0);
    refresh();

    WINDOW* hwin = newwin(2, COLS, 0, 0);
    WINDOW* fwin = newwin(1, COLS, LINES - 1, 0);

    mvwprintw(hwin, 0, cast(int) (COLS - HEADER.length) / 2, "%s", HEADER.toStringz);
    mvwchgat(hwin, 0, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);
    wrefresh(hwin);

    WINDOW* content = newwin(LINES - 3, COLS - 4, 2, 2);
    
    int input;
    GradeContainer currGC = new Gradebook();
    int selected = 0;

    (cast(Gradebook) currGC).addCourse(new Course("CSCI 5980"));
    (cast(Gradebook) currGC).addCourse(new Course("STAT 3021"));

    while(true) {
        werase(fwin);
        mvwprintw(fwin, 0, FOOTER_OFFSET, "[a]dd, [d]elete, [e]dit, [q]uit, go [u]p");
        mvwchgat(fwin, 0, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);
        wrefresh(fwin);

        mvwprintw(hwin, 1, 0, "%s", headline(currGC).toStringz);
        wrefresh(hwin);

        wprintmenu(content, map!(x => x.entry)(currGC.members).array, selected);
        wrefresh(content);

        input = getch();

        switch(input) {
        case 'q', 'Q':
            goto end;
        case 'a', 'A':
        case 'd', 'D':
        case 'e', 'E':
        case KEY_LEFT, 'u', 'U':
            currGC.parent(currGC);
            break;
        case KEY_RIGHT, 0xA:
            currGC.select(selected, currGC);
            break;
        case KEY_UP:
            selected = max(selected - 1, 0);
            break;
        case KEY_DOWN:
            selected = min(selected + 1, currGC.members.length - 1).max(0);
            break;
        default:
        }
    }

    end:
    delwin(fwin);
    delwin(hwin);
    delwin(content);
    endwin();

    return 0;
}
