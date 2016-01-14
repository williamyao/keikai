import deimos.ncurses.curses;
import std.conv;
import std.string;
import std.format;
import std.algorithm.iteration, std.algorithm.comparison;
import std.string;
import std.array;
import std.json;
import std.file, std.path;
import core.thread;

interface Scorable {
public:
    double score();
    string entry();

    @property string description();
    @property string description(string);
}

interface GradeContainer : InteractiveContainer {
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

    string entry() {
        string name = description == "" ? "<Unnamed>" : description;
        return format("%s [%.2f%% (%.0f/%.0f)]", name, score, points, maxPoints);
    }

    T opCast(T : JSONValue)() {
        JSONValue v = JSONValue(["class": "Grade"]);

        v["points"] = points;
        v["maxPoints"] = maxPoints;
        v["description"] = description;

        return v;
    }

    static Grade fromJSON(JSONValue v)
    in {
        assert("class" in v);

        JSONValue cls = v["class"];

        assert(cls.type == JSON_TYPE.STRING);
        assert(cls.str == "Grade");

        assert("points" in v);
        assert("maxPoints" in v);
        assert("description" in v);
    }
    body {
        double points, maxPoints;

        switch(v["points"].type) {
        case JSON_TYPE.INTEGER:
            points = v["points"].integer;
            break;
        case JSON_TYPE.FLOAT:
            points = v["points"].floating;
            break;
        default:
        }

        switch(v["points"].type) {
        case JSON_TYPE.INTEGER:
            maxPoints = v["maxPoints"].integer;
            break;
        case JSON_TYPE.FLOAT:
            maxPoints = v["maxPoints"].floating;
            break;
        default:
        }

        return new Grade(points, maxPoints, v["description"].str);
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

    string entry() {
        string name = description == "" ? "<Unnamed>" : description;
        if(grades.length == 0)
            return format("%s [empty, weighted %.0f%%]", name, weight * 100);
        else
            return format("%s [%.2f%% (%.0f/%.0f), weighted %.0f%%] ",
                          name,
                          score,
                          points,
                          maxPoints,
                          weight * 100);
    }

    Scorable[] members() {
        Scorable[] view;
        view.length = grades.length;
        foreach(i, g; grades) view[i] = g;
        return view;
    }

    bool select(in int index, ref GradeContainer down) {
        return false;
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

    void wpromptadd(WINDOW* scr, int index) {
        string description = promptString(scr, "Description for this new grade: ");
        double maxPoints = promptDouble(scr, "Maximum point value: ");
        double points = promptDouble(scr, "Earned point value: ");

        addGrade(new Grade(points, maxPoints, description));
    }

    void wpromptdel(WINDOW* scr, int index) {
        if(index < grades.length) {
            string name = grades[index].description;
            name = name == "" ? "this unnamed grade" : format("'%s'", name);

            while(true) {
                int input = promptInput(scr, format("Are you sure you want to delete %s? (y/n)", name));

                switch(input) {
                case 'y', 'Y':
                    grades = grades[0..index] ~ grades[index + 1..$];
                case 'n', 'N':
                    return;
                default:
                }
            }
        } else displayError(scr, "Nothing to delete!");
    }

    void wpromptedit(WINDOW* scr, int index) {
        if(index < grades.length) {
            Grade g = grades[index];
            
            g.description = promptString(scr, "New description (<ENTER> to leave unchanged): ", g.description);
            g.maxPoints = promptDouble(scr, "New maximum point value (<ENTER> to leave unchanged): ", g.maxPoints);
            g.points = promptDouble(scr, "New earned point value (<ENTER> to leave unchanged): ", g.points);
        } else displayError(scr, "Nothing to edit!");
    }

    T opCast(T : JSONValue)() {
        JSONValue v = JSONValue(["class": "Category"]);

        v["weight"] = weight;
        v["description"] = description;
        v["grades"] = grades.map!(x => cast(JSONValue) x).array;

        return v;
    }

    static Category fromJSON(JSONValue v)
    in {
        assert("class" in v);

        JSONValue cls = v["class"];

        assert(cls.type == JSON_TYPE.STRING);
        assert(cls.str == "Category");

        assert("grades" in v);
        assert(v["grades"].type == JSON_TYPE.ARRAY);

        assert("weight" in v);
        assert("description" in v);
    }
    body {
        double weight;

        switch(v["weight"].type) {
        case JSON_TYPE.INTEGER:
            weight = v["weight"].integer;
            break;
        case JSON_TYPE.FLOAT:
            weight = v["weight"].floating;
            break;
        default:
        }

        Category c = new Category(weight, v["description"].str);

        foreach(g; v["grades"].array) {
            c.addGrade(Grade.fromJSON(g));
        }

        return c;
    }

    mixin(property!(double, q{weight}));
    mixin(property!(string, q{description}));
    mixin(property!(Course, q{up}));

    this(double weight, string description) {
        this._weight = weight;
        this._description = description;
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

    string entry() {
        string name = description == "" ? "<Unnamed>" : description;

        if(categories.length == 0)
            return format("%s [empty]", name);
        else
            return format("%s [%.2f%%]", name, score);
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

    void wpromptadd(WINDOW* scr, int index) {
        string description = promptString(scr, "Description for this new category: ");
        double weight = promptDouble(scr, "Percentage of final grade: ") / 100;

        addCategory(new Category(weight, description));
    }

    void wpromptdel(WINDOW* scr, int index) {
        if(index < categories.length) {
            string name = categories[index].description;
            name = name == "" ? "this unnamed category" : format("'%s'", name);

            while(true) {
                int input = promptInput(scr, format("Are you sure you want to delete %s? (y/n)", name));

                switch(input) {
                case 'y', 'Y':
                    categories = categories[0..index] ~ categories[index + 1..$];
                case 'n', 'N':
                    return;
                default:
                }
            }
        } else displayError(scr, "Nothing to delete!");
    }

    void wpromptedit(WINDOW* scr, int index) {
        if(index < categories.length) {
            Category c = categories[index];

            c.description = promptString(scr, "New description (<ENTER> to leave unchanged): ", c.description);
            c.weight = promptDouble(scr, "New percentage of final grade (<ENTER> to leave unchanged): ", c.weight * 100) / 100;
        } else displayError(scr,"Nothing to edit!");
    }

    this(string description) {
        this.description = description;
    }

    void addCategory(Category c) {
        categories ~= c;
        c.up = this;
    }

    T opCast(T : JSONValue)() {
        JSONValue v = JSONValue(["class": "Course"]);

        v["description"] = description;
        v["categories"] = categories.map!(x => cast(JSONValue) x).array;

        return v;
    }

    static Course fromJSON(JSONValue v)
    in {
        assert("class" in v);

        JSONValue cls = v["class"];

        assert(cls.type == JSON_TYPE.STRING);
        assert(cls.str == "Course");

        assert("categories" in v);
        assert(v["categories"].type == JSON_TYPE.ARRAY);

        assert("description" in v);
    }
    body {
        Course c = new Course(v["description"].str);

        foreach(cat; v["categories"].array) {
            c.addCategory(Category.fromJSON(cat));
        }

        return c;
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
            return true;
        } else return false;
    }

    bool parent(ref GradeContainer up) {
        return false;
    }

    string _headline() {
        return "All courses";
    }

    void wpromptadd(WINDOW* scr, int index) {
        string description = promptString(scr, "Description for this new course: ");

        addCourse(new Course(description));
    }

    void wpromptdel(WINDOW* scr, int index) {
        if(index < courses.length) {
            string name = courses[index].description;
            name = name == "" ? "this unnamed course" : format("'%s'", name);

            while(true) {
                int input = promptInput(scr, format("Are you sure you want to delete %s? (y/n)", name));

                switch(input) {
                case 'y', 'Y':
                    courses = courses[0..index] ~ courses[index + 1..$];
                case 'n', 'N':
                    return;
                default:
                }
            }
        } else displayError(scr, "Nothing to delete!");
    }

    void wpromptedit(WINDOW* scr, int index) {
        if(index < courses.length) {
            Course c = courses[index];

            c.description = promptString(scr, "New description (<ENTER> to leave unchanged): ", c.description);
        } else displayError(scr, "Nothing to edit!");
    }

    T opCast(T : JSONValue)() {
        JSONValue v = JSONValue(["class": "Gradebook"]);

        v["courses"] = courses.map!(x => cast(JSONValue) x).array;

        return v;
    }

    static Gradebook fromJSON(JSONValue v)
    in {
        assert("class" in v);

        JSONValue cls = v["class"];

        assert(cls.type == JSON_TYPE.STRING);
        assert(cls.str == "Gradebook");

        assert("courses" in v);
        assert(v["courses"].type == JSON_TYPE.ARRAY);
    }
    body {
        Gradebook gc = new Gradebook();

        foreach(c; v["courses"].array) {
            gc.addCourse(Course.fromJSON(c));
        }

        return gc;
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

void displayError(WINDOW* scr, string errormsg) {
    werase(scr);
    mvwchgat(scr, 0, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);
    wattron(scr, A_REVERSE);

    mvwprintw(scr, 0, FOOTER_OFFSET, "%s", errormsg.toStringz);
    wrefresh(scr);

    Thread.sleep(dur!"msecs"(ERROR_DISPLAY_DURATION_MS));
}

int promptInput(WINDOW* scr, string prompt) {
    werase(scr);
    mvwchgat(scr, 0, 0, -1, A_REVERSE, cast(short) 0, cast(void*) null);
    wattron(scr, A_REVERSE);

    mvwprintw(scr, 0, FOOTER_OFFSET, "%s", prompt.toStringz);
    wrefresh(scr);

    return getch();
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

string promptString(WINDOW* scr, string prompt, string def) {
    string input = promptString(scr, prompt);

    if(input == "") return def;
    else return input;
}

double promptDouble(WINDOW* scr, string prompt) {
    while(true) {
        try return to!double(promptString(scr, prompt));
        catch(ConvException e) displayError(scr, "That doesn't seem to be a number.");
    }
}

double promptDouble(WINDOW* scr, string prompt, double def) {
    while(true) {
        try {
            string input = promptString(scr, prompt);
            if(input == "") return def;
            else return to!double(input);
        } catch(ConvException e) displayError(scr, "That doesn't seem to be a number.");
    }
}

enum HEADER = "keikai 1.0.0";
enum MAX_INPUT_LENGTH = 80;
enum FOOTER_OFFSET = 2;
enum ERROR_DISPLAY_DURATION_MS = 1_250;

string databasePath() {
    version(Windows) {
        return "keikai_grades.json";
    } else {
        return expandTilde("~/.keikai/keikai_grades.json");
    }
}

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
    int selected = 0;

    string dbpath = databasePath();

    Gradebook top;

    if(exists(dbpath)) {
        top = Gradebook.fromJSON((cast(string) dbpath.read).parseJSON);
    } else {
        top = new Gradebook();

        mkdirRecurse(dbpath.dirName);
        write(dbpath, "");
    }

    GradeContainer currGC = top;

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
            currGC.wpromptadd(fwin, selected);
            break;
        case 'd', 'D':
            currGC.wpromptdel(fwin, selected);
            selected = max(selected - 1, 0);
            break;
        case 'e', 'E':
            currGC.wpromptedit(fwin, selected);
            break;
        case KEY_LEFT, 'u', 'U':
            if(currGC.parent(currGC)) selected = 0;
            break;
        case KEY_RIGHT, 0xA:
            if(currGC.select(selected, currGC)) selected = 0;
            break;
        case KEY_UP:
            selected = max(selected - 1, 0);
            break;
        case KEY_DOWN:
            selected = max(0, min(selected + 1, (cast(int) currGC.members.length) - 1));
            break;
        case '1': .. case '9':
            if(currGC.select(input - '1', currGC)) selected = 0;
            break;
        case '0':
            if(currGC.select(9, currGC)) selected = 0;
            break;
        default:
        }
    }

    end:
    delwin(fwin);
    delwin(hwin);
    delwin(content);
    endwin();

    write(dbpath, (cast(JSONValue) top).toPrettyString);

    return 0;
}
