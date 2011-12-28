
dnl yaml.m4
dnl   Autoconf macros for LibYAML.
dnl 
dnl Copyright (C) 2008 Michael Imamura <zoogie@lugatgt.org>
dnl All rights reserved.
dnl 
dnl Redistribution and use in source and binary forms, with or
dnl without modification, are permitted provided that the following
dnl conditions are met:
dnl
dnl * Redistributions of source code must retain the above copyright
dnl   notice, this list of conditions and the following disclaimer.
dnl * Redistributions in binary form must reproduce the above copyright
dnl   notice, this list of conditions and the following disclaimer in
dnl   the documentation and/or other materials provided with the
dnl   distribution.
dnl * Neither the name of the author nor the names of its contributors
dnl   may be used to endorse or promote products derived from this
dnl   software without specific prior written permission.
dnl
dnl THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
dnl "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
dnl LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
dnl FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
dnl COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
dnl INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
dnl BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
dnl OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
dnl AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
dnl LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
dnl ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
dnl POSSIBILITY OF SUCH DAMAGE.

dnl Modified slightly by Jan Schreiber <jans@ravn.no>

dnl YAML_REQUIRE()
dnl Check for LibYAML, with support for alternate install locations
dnl via "--with-yaml=".
dnl If found, YAML_CPPFLAGS and YAML_LDFLAGS will be set.
AC_DEFUN([YAML_REQUIRE],
[
dnl Required LibYAML version.
dnl TODO: Make this configurable.
yaml_ver_major=0
yaml_ver_minor=1
yaml_ver_patch=1
yaml_ver_str="$yaml_ver_major.$yaml_ver_minor.$yaml_ver_patch"
AC_ARG_WITH([yaml],
	AC_HELP_STRING([--with-yaml=DIR],
		[prefix for LibYAML library and headers]),
	[
		dnl We need to make sure that distcheck uses the same setting
		dnl otherwise it will fail.
		AC_SUBST([DISTCHECK_CONFIGURE_FLAGS],
			["$DISTCHECK_CONFIGURE_FLAGS '--with-yaml=$with_yaml'"])
	])
# Search for LibYAML.
AC_CACHE_CHECK([for LibYAML version >= $yaml_ver_str], [yaml_cv_path],
	[
		AC_LANG_PUSH([C])
		yaml_cv_path=no
		for yaml_dir in "$with_yaml" '' /usr/local /usr
		do
			yaml_save_CPPFLAGS="$CPPFLAGS"
			yaml_save_LDFLAGS="$LDFLAGS"
			if test x"$yaml_dir" != x
			then
				test -e "$yaml_dir/include/yaml.h" || continue
				CPPFLAGS="$CPPFLAGS -I$yaml_dir/include"
				LDFLAGS="$LDFLAGS -L$yaml_dir/lib -Wl,-rpath,$yaml_dir/lib -lyaml"
			fi
			dnl Unfortunately, there doesn't seem to be a way to check
			dnl the library version other than to actually run a test
			dnl program.
			dnl TODO: Handle case where we are cross-compiling.
                        AC_CHECK_HEADERS(yaml.h)
			AC_RUN_IFELSE([AC_LANG_PROGRAM([[
#include <yaml.h>
				]],[[
int ver_major = 0, ver_minor = 0, ver_patch = 0;
yaml_get_version(&ver_major, &ver_minor, &ver_patch);
if (ver_major < $yaml_ver_major) return 1;
if (ver_minor < $yaml_ver_minor) return 1;
if (ver_patch < $yaml_ver_patch) return 1;
				]])],
				[yaml_cv_path=yes],
				[yaml_cv_path=no])
			CPPFLAGS="$yaml_save_CPPFLAGS"
			LDFLAGS="$yaml_save_LDFLAGS"
			if test x"$yaml_cv_path" = xyes
			then
				yaml_cv_path="$yaml_dir"
				break
			fi
		done
		AC_LANG_POP([C])
	])
if test x"$yaml_cv_path" = xno
then
	AC_MSG_ERROR([Could not find LibYAML version >= $yaml_ver_str; try using --with-yaml=/path/to/libyaml])
elif test x"$yaml_cv_path" = x
then
	YAML_CPPFLAGS=
	YAML_LDFLAGS=
else
	YAML_CPPFLAGS="-I$yaml_cv_path/include"
	YAML_LDFLAGS="-L$yaml_cv_path/lib -lyaml"
fi
AC_SUBST([YAML_CPPFLAGS])
AC_SUBST([YAML_LDFLAGS])
])

