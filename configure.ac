# Run this through `autoconf' to produce a portable configuration
# file.

AC_INIT([keikai], [version-1.0.1])

AC_PREREQ([2.69])

AC_MSG_NOTICE([checking for a D2 compiler])
AC_CHECK_PROGS([DC], [dmd ldc2 gdc])

if test "$DC" = ""
then
	AC_MSG_ERROR([Could not find a compiler for the D language.])
fi

AC_MSG_NOTICE([checking if D compiler is for D2])

AC_CHECK_PROG([MKTEMP], [mktemp], [mktemp])
if test -d /tmp
then
	export TMP=/tmp
fi

if test -n "$MKTEMP" -a -n "$TMP"
then
	export TEMPIN=$($MKTEMP "$TMP/keikaiXXXXXX.d")
export TEMPOUT=$($MKTEMP "$TMP/keikaiXXXXXX.o")
elif test -n "$MKTEMP"
then
	export TEMPIN=$($MKTEMP "./keikaiXXXXXX.d")
	export TEMPOUT=$($MKTEMP "./keikaiXXXXXX.o")
elif test -n "$TMP"
then
	AC_MSG_WARN([Creating temp files in /tmp, may have collision])
	export TEMPIN="$TMP/keikaitemp.d"
	export TEMPOUT="$TMP/keikaitemp.o"
else
	AC_MSG_WARN([Creating temp files in current directory, may have collision])
	export TEMPIN="./keikaitemp.d"
	export TEMPOUT="./keikaitemp.o"
fi

exec 3>"$TEMPIN"
exec 3>"$TEMPOUT"

AC_MSG_CHECKING([that D compiler is for D2])

echo "immutable(int) foo = 2;" > "$TEMPIN"
if $DC -c -of"$TEMPOUT" "$TEMPIN"
then
	AC_MSG_RESULT([yes])
else
	AC_MSG_RESULT([no])
	AC_MSG_ERROR([Keikai requires a compiler for the D language, second edition.])
fi

rm "$TEMPIN" "$TEMPOUT"

AC_MSG_NOTICE([checking if noweb is installed])

AC_CHECK_PROG([WEAVE], [noweave], [noweave])
AC_CHECK_PROG([TANGLE], [notangle], [notangle])

if test "$WEAVE" = "" -o "$TANGLE" = ""
then
	AC_MSG_ERROR([Keikai requires noweb to be installed.])
fi

AC_SEARCH_LIBS([mvwprintw], [ncursesw ncurses curses],,
	[AC_MSG_ERROR([Keikai requires a curses library to be installed.])])

AC_ARG_VAR([DC], [compiler for D2])
AC_ARG_VAR([WEAVE], [extracts TeX documentation from literate source files])
AC_ARG_VAR([TANGLE], [extracts program source from literate source files])

AC_CONFIG_FILES([Makefile])

AC_OUTPUT
