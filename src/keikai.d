import deimos.ncurses.curses;
import std.conv;
import std.string;
import std.format;
import std.algorithm.iteration, std.algorithm.comparison;
import std.string;
import std.array;

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

string header = "keikai 0.0.1";

int main(string[] args) {
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, true);
    curs_set(0);
    refresh();

    WINDOW* hwin = newwin(2, COLS, 0, 0);
    WINDOW* fwin = newwin(1, COLS, LINES - 1, 0);

    mvwprintw(hwin, 0, cast(int) (COLS - header.length) / 2, "%s", header.toStringz);
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
        mvwprintw(fwin, 0, 2, "[a]dd, [d]elete, [e]dit, [q]uit, go [u]p");
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
    endwin();

    return 0;
}
