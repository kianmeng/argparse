%%%-------------------------------------------------------------------
%%% @author dane
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 27. Jan 2019 11:27
%%%-------------------------------------------------------------------
-module(argparse_SUITE).
-author("maximfca@gmail.com").

-export([suite/0, all/0, groups/0]).

-export([
    basic/0, basic/1,
    single_arg_built_in_types/0, single_arg_built_in_types/1,
    complex_command/0, complex_command/1,
    errors/0, errors/1,
    args/0, args/1,
    argparse/0, argparse/1,
    negative/0, negative/1,
    python_issue_15112/0, python_issue_15112/1,
    type_validators/0, type_validators/1,
    error_format/0, error_format/1
]).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").


suite() ->
    [{timetrap, {seconds, 10}}].

groups() ->
    [{parallel, [parallel], [
        basic, single_arg_built_in_types, complex_command, errors, args, argparse, negative,
        python_issue_15112, type_validators
    ]}].

all() ->
    [{group, parallel}].

%%--------------------------------------------------------------------
%% Helpers

%% very complex option map - basically having everything in it!
opt_map() ->
    #{options => [
        %% options
        #{name => string, short => $s, long => "-string", action => append, help => "String list option"},
        #{name => boolean, type => boolean, short => $b, action => append, help => "Boolean list option"},
        #{name => float, type => float, short => $f, long => "-float", action => append, help => "Float option"},
        %% positional args
        #{name => integer, type => int, help => "Integer variable"},
        #{name => string, help => "alias for string option", action => extend, nargs => list}
    ]}.

parse_opts(Args, Opts) ->
    argparse:parse(string:lexemes(Args, " "), #{options => Opts}).

parse(Args, Command) ->
    argparse:parse(string:lexemes(Args, " "), Command).

parse_cmd(Args, Command) ->
    argparse:parse(string:lexemes(Args, " "), #{commands => Command}).

%%--------------------------------------------------------------------
%% Test Cases

basic() ->
    [{doc, "Basic cases"}].

basic(Config) when is_list(Config) ->
    %% empty command
    ?assertEqual({[{cmd, #{}}], #{}}, parse("cmd", #{commands => #{cmd => #{}}})),
    %% sub-command
    ?assertEqual({[{sub,#{}},{cmd,#{commands => #{sub => #{}}}}], #{}},
        parse("cmd sub", #{commands => #{cmd => #{commands => #{sub => #{}}}}})),
    %% command with positional argument
    PosCmd = #{options => [#{name => pos}]},
    ?assertEqual({[{cmd, PosCmd}], #{pos => "arg"}}, parse(["cmd arg"],
        #{commands => #{cmd => PosCmd}})),
    %% command with optional argument
    OptCmd = #{options => [#{name => force, short => $f, type => boolean}]},
    ?assertEqual({[{rm, OptCmd}], #{force => true}},
        parse(["rm -f"], #{commands => #{rm => OptCmd}}), "rm -f"),
    %% command with optional and positional argument
    PosOptCmd = #{options => [#{name => force, short => $f, type => boolean}, #{name => dir}]},
    ?assertEqual({[{rm, PosOptCmd}], #{force => true, dir => "dir"}},
        parse(["rm -f dir"], #{commands => #{rm => PosOptCmd}}), "rm -f dir"),
    %% no command, just argument list
    Kernel = #{name => kernel, long => "kernel", type => atom, nargs => 2},
    ?assertEqual({undefined, #{kernel => [port, dist]}},
        parse(["-kernel port dist"], #{options => [Kernel]})),
    %% same but positional
    ArgList = #{name => arg, nargs => 2, type => boolean},
    ?assertEqual({undefined, #{arg => [true, false]}},
        parse(["true false"], #{options => [ArgList]})).

single_arg_built_in_types() ->
    [{doc, "Tests all built-in types supplied as a single argument"}].

% built-in types testing
single_arg_built_in_types(Config) when is_list(Config) ->
    BoolCmd = #{options => [#{name => meta, type => boolean, short => $b, long => "-boolean"}]},
    CmdMap = #{bool => BoolCmd},
    ?assertEqual({[{bool, BoolCmd}], #{}}, parse_cmd(["bool"], CmdMap)),
    ?assertEqual({[{bool, BoolCmd}], #{meta => true}}, parse_cmd(["bool -b"], CmdMap)),
    ?assertEqual({[{bool, BoolCmd}], #{meta => true}}, parse_cmd(["bool --boolean"], CmdMap)),
    ?assertEqual({[{bool, BoolCmd}], #{meta => false}}, parse_cmd(["bool --boolean false"], CmdMap)),
    %% ?assertEqual({BoolCmd, #{meta => false}}, ectl_opt:parse(["bool", "--boolean=false"], CmdMap)).
    %% integer tests
    IntCmd = #{options => [#{name => int, type => int, short => $i, long => "-int"}]},
    IntCmdMap = #{integer => IntCmd},
    ?assertEqual({[{integer, IntCmd}], #{int => 1}}, parse_cmd(["integer -i 1"], IntCmdMap)),
    ?assertEqual({[{integer, IntCmd}], #{int => 1}}, parse_cmd(["integer --int 1"], IntCmdMap)),
    %% negative integers
    ?assertEqual({[{integer, IntCmd}], #{int => -1}}, parse_cmd(["integer -i -1"], IntCmdMap)),
    %% floating point
    FloatCmd = #{options => [#{name => f, type => float, short => $f}]},
    FloatCmdMap = #{float => FloatCmd},
    ?assertEqual({[{float, FloatCmd}], #{f => 44.44}}, parse_cmd(["float -f 44.44"], FloatCmdMap)),
    %% atoms, existing
    AtomCmd = #{options => [#{name => atom, type => atom, short => $a, long => "-atom"}]},
    AtomCmdMap = #{atom_cmd => AtomCmd},
    ?assertEqual({[{atom_cmd, AtomCmd}], #{atom => atom}}, parse_cmd(["atom_cmd -a atom"], AtomCmdMap)),
    ?assertEqual({[{atom_cmd, AtomCmd}], #{atom => atom}}, parse_cmd(["atom_cmd --atom atom"], AtomCmdMap)),
    %% binary
    %put(ectl, [#{name => "binary", options = [#{name => binary, type = binary}]}]),
    %?assertEqual(<<"bin">>, ectl_start:ectl_start(["binary", "bin"])),
    ok.

type_validators() ->
    [{doc, "Validators for built-in types"}].


type_validators(Config) when is_list(Config) ->
    %% {float, [{min, float()} | {max, float()}]} |
    ?assertException(error, {invalid_argument,undefined,float, 0.0},
        parse_opts("0.0", [#{name => float, type => {float, [{min, 1.0}]}}])),
    ?assertException(error, {invalid_argument,undefined,float, 2.0},
        parse_opts("2.0", [#{name => float, type => {float, [{max, 1.0}]}}])),
    %% {int, [{min, integer()} | {max, integer()}]} |
    ?assertException(error, {invalid_argument,undefined,int, 10},
        parse_opts("10", [#{name => int, type => {int, [{min, 20}]}}])),
    ?assertException(error, {invalid_argument,undefined,int, -5},
        parse_opts("-5", [#{name => int, type => {int, [{max, -10}]}}])),
    %% string: regex & regex with options
    %% {string, string()} | {string, string(), []}
    ?assertException(error, {invalid_argument,undefined,str, "me"},
        parse_opts("me", [#{name => str, type => {string, "me.me"}}])),
    ?assertException(error, {invalid_argument,undefined,str, "me"},
        parse_opts("me", [#{name => str, type => {string, "me.me", []}}])),
    %% {binary, {re, binary()} | {re, binary(), []}
    ?assertException(error, {invalid_argument,undefined, bin, "me"},
        parse_opts("me", [#{name => bin, type => {binary, <<"me.me">>}}])),
    ?assertException(error, {invalid_argument,undefined,bin, "me"},
        parse_opts("me", [#{name => bin, type => {binary, <<"me.me">>, []}}])),
    ok.

complex_command() ->
    [{doc, "Parses a complex command that has a mix of optional and positional arguments"}].

complex_command(Config) when is_list(Config) ->
    OptMap = opt_map(),
    CmdMap = #{start => OptMap},
    Parsed = parse_cmd("start --float 1.04 -f 112 -b -b -s s1 42 --string s2 s3 s4", CmdMap),
    Expected = {[{start, OptMap}], #{float => [1.04, 112], boolean => [true, true], integer => 42, string => ["s1", "s2", "s3", "s4"]}},
    ?assertEqual(Expected, Parsed).

errors() ->
    [{doc, "Tests for various errors, missing arguments etc"}].

errors(Config) when is_list(Config) ->
    %% conflicting option names
    ?assertException(error, {invalid_option, _, two, "short conflicting with one"},
        parse("", #{options => [#{name => one, short => $$}, #{name => two, short => $$}]})),
    ?assertException(error, {invalid_option, _, two, "long conflicting with one"},
        parse("", #{options => [#{name => one, long => "a"}, #{name => two, long => "a"}]})),
    %% unknown option at the top of the path
    ?assertException(error, {unknown_option, undefined, "arg"},
        parse_cmd(["arg"], #{})),
    %% positional argument missing
    Opt = #{name => mode, required => true},
    ?assertException(error, {missing_argument, _, mode},
        parse_cmd(["start"], #{start => #{options => [Opt]}})),
    %% optional argument missing
    Opt1 = #{name => mode, short => $o, required => true},
    ?assertException(error, {missing_argument, _, mode},
        parse_cmd(["start"], #{start => #{options => [Opt1]}})),
    %% atom that does not exist
    Opt2 = #{name => atom, type => atom},
    ?assertException(error, {invalid_argument, _, atom, "boo-foo"},
        parse_cmd(["start boo-foo"], #{start => #{options => [Opt2]}})),
    %% optional argument missing some items
    Opt3 = #{name => kernel, long => "kernel", type => atom, nargs => 2},
    ?assertException(error, {invalid_argument, _, kernel, ["port"]},
        parse_cmd(["start -kernel port"], #{start => #{options => [Opt3]}})),
    %% positional argument missing some items
    Opt4 = #{name => arg, type => atom, nargs => 2},
    ?assertException(error, {invalid_argument, _, arg, ["p1"]},
    parse_cmd(["start p1"], #{start => #{options => [Opt4]}})).

args() ->
    [{doc, "Tests argument consumption option, with nargs"}].

args(Config) when is_list(Config) ->
    %% consume optional list arguments
    Opts = [
        #{name => arg, short => $s, nargs => list, type => int},
        #{name => bool, short => $b, type => boolean}
    ],
    ?assertEqual({undefined, #{arg => [1, 2, 3], bool => true}},
        parse_opts(["-s 1 2 3 -b"], Opts)),
    %% consume one_or_more arguments in an optional list
    Opts2 = [
        #{name => arg, short => $s, nargs => nonempty_list},
        #{name => extra, short => $x}
        ],
    ?assertEqual({undefined, #{extra => "X", arg => ["a","b","c"]}},
        parse_opts(["-s port -s a b c -x X"], Opts2)),
    %% error if there is no argument to consume
    ?assertException(error, {invalid_argument, undefined, arg, ["-x"]},
        parse_opts(["-s -x"], Opts2)),
    %% positional arguments consumption: one or more positional argument
    OptsPos1 = [
        #{name => arg, nargs => nonempty_list},
        #{name => extra, short => $x}
    ],
    ?assertEqual({undefined, #{extra => "X", arg => ["b","c"]}},
        parse_opts(["-x port -x a b c -x X"], OptsPos1)),
    %% positional arguments consumption, any number (maybe zero)
    OptsPos2 = [
        #{name => arg, nargs => list},
        #{name => extra, short => $x}
    ],
    ?assertEqual({undefined, #{extra => "X", arg => ["a","b","c"]}},
        parse_opts(["-x port a b c -x X"], OptsPos2)),
    %% positional: consume ALL arguments!
    OptsAll = [
        #{name => arg, nargs => all},
        #{name => extra, short => $x}
    ],
    ?assertEqual({undefined, #{extra => "port", arg => ["a","b","c", "-x", "X"]}},
        parse_opts(["-x port a b c -x X"], OptsAll)),
    %%
    OptMaybe = [
        #{name => foo, long => "-foo", nargs => {maybe, c}, default => d},
        #{name => bar, nargs => maybe, default => d}
    ],
    ?assertEqual({undefined, #{foo => "YY", bar => "XX"}},
        parse_opts(["XX --foo YY"], OptMaybe)),
    ?assertEqual({undefined, #{foo => c, bar => "XX"}},
        parse_opts(["XX --foo"], OptMaybe)),
    ?assertEqual({undefined, #{foo => d, bar => d}},
        parse_opts([""], OptMaybe)).

argparse() ->
    [{doc, "Tests examples from argparse Python library"}].

argparse(Config) when is_list(Config) ->
    Parser = #{options => [
        #{name => sum, long => "-sum", action => {store, sum}, default => max},
        #{name => integers, type => int, nargs => nonempty_list}
        ]},
    ?assertEqual({undefined, #{integers => [1, 2, 3, 4], sum => max}}, parse("1 2 3 4", Parser)),
    ?assertEqual({undefined, #{integers => [1, 2, 3, 4], sum => sum}}, parse("1 2 3 4 --sum", Parser)),
    ?assertEqual({undefined, #{integers => [7, -1, 42], sum => sum}}, parse("--sum 7 -1 42", Parser)),
    %% name or flags
    Parser2 = #{options => [
        #{name => bar, required => true},
        #{name => foo, short => $f, long => "-foo"}
    ]},
    ?assertEqual({undefined, #{bar => "BAR"}}, parse("BAR", Parser2)),
    ?assertEqual({undefined, #{bar => "BAR", foo => "FOO"}}, parse("BAR --foo FOO", Parser2)),
    %PROG: error: the following arguments are required: bar
    ?assertException(error, {missing_argument, undefined, bar}, parse("--foo FOO", Parser2)),
    %% action tests: default
    ?assertEqual({undefined, #{foo => "1"}},
        parse("--foo 1", #{options => [#{name => foo, long => "-foo"}]})),
    %% action test: store
    ?assertEqual({undefined, #{foo => 42}},
        parse("--foo", #{options => [#{name => foo, long => "-foo", action => {store, 42}}]})),
    %% action tests: boolean (variants)
    ?assertEqual({undefined, #{foo => true}},
        parse("--foo", #{options => [#{name => foo, long => "-foo", action => {store, true}}]})),
    ?assertEqual({undefined, #{foo => true}},
        parse("--foo", #{options => [#{name => foo, long => "-foo", type => boolean}]})),
    ?assertEqual({undefined, #{foo => true}},
        parse("--foo true", #{options => [#{name => foo, long => "-foo", type => boolean}]})),
    ?assertEqual({undefined, #{foo => false}},
        parse("--foo false", #{options => [#{name => foo, long => "-foo", type => boolean}]})),
    %% action tests: append & append_const
    ?assertEqual({undefined, #{all => [1, "1"]}},
        parse("--x 1 -x 1", #{options => [
            #{name => all, long => "-x", type => int, action => append},
            #{name => all, short => $x, action => append}]})),
    ?assertEqual({undefined, #{all => ["Z", 2]}},
        parse("--x -x", #{options => [
            #{name => all, long => "-x", action => {append, "Z"}},
            #{name => all, short => $x, action => {append, 2}}]})),
    %% count:
    ?assertEqual({undefined, #{v => 3}},
        parse("-v -v -v", #{options => [#{name => v, short => $v, action => count}]})),
    ok.

negative() ->
    [{doc, "Test negative number parser"}].

negative(Config) when is_list(Config) ->
    Parser = #{options => [
        #{name => x, short => $x, type => int},
        #{name => foo, nargs => maybe}
    ]},
    ?assertEqual({undefined, #{x => -1}}, parse("-x -1", Parser)),
    ?assertEqual({undefined, #{x => -1, foo => "-5"}}, parse("-x -1 -5", Parser)),
    %%
    Parser2 = #{options => [
        #{name => one, short => $1},
        #{name => foo, nargs => maybe}
    ]},

    %% negative number options present, so -1 is an option
    ?assertEqual({undefined, #{one => "X"}}, parse("-1 X", Parser2)),
    %% negative number options present, so -2 is an option
    ?assertException(error, {unknown_option, undefined, "-2"}, parse("-2", Parser2)),

    %% negative number options present, so both -1s are options
    ?assertException(error, {missing_argument,undefined,one}, parse("-1 -1", Parser2)),
    %usage: PROG [-h] [-1 ONE] [foo]
    %PROG: error: argument -1: expected one argument
    ok.

python_issue_15112() ->
    [{doc, "Tests for https://bugs.python.org/issue15112"}].

python_issue_15112(Config) when is_list(Config) ->
    Parser = #{options => [
        #{name => pos},
        #{name => foo},
        #{name => spam, default => 24, type => int, long => "-spam"},
        #{name => vars, nargs => list}
    ]},
    ?assertEqual({undefined, #{pos => "1", foo => "2", spam => 8, vars => ["8", "9"]}},
        parse("1 2 --spam 8 8 9", Parser)).

error_format() ->
    [{doc, "Tests error output formatter"}].

error_format(Config) when is_list(Config) ->
    %% format
    ok.

%format_error({invalid_command, Path, Text}) ->
%    lists:flatten(io_lib:format("~p invalid command (~s)", [Path, Text]));
%format_error({invalid_option, Path, Text, Option}) ->
%    lists:flatten(io_lib:format("~p invalid option ~p (~s)", [Path, Option, Text]));
%format_error({unknown_option, Path, Argument}) ->
%    lists:flatten(io_lib:format("~p unknown option ~s", [Path, Argument]));
%format_error({missing_argument, Path, Option}) ->
%    lists:flatten(io_lib:format("~p missing option ~s", [Path, Option]));
%format_error({invalid_argument, Path, Option, Value}) ->
%    lists:flatten(io_lib:format("~p invalid option ~s (~p)", [Path, Option, Value])).