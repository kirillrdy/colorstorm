const std = @import("std");
const cli = @import("cli.zig");
const utils = @import("utils.zig");
const templator = @import("templator.zig");

var a: std.mem.Allocator = undefined;
const io = std.io;
const stdout = std.io.getStdOut().writer();

const help =
    \\USAGE:
    \\$ colorstorm [-o outdir] [-g generator] input
    \\
    \\-o|--outdir: The directory to output themes to (default: "./colorstorm-out")
    \\-g|--gen:    Generator type (default: all)
    \\             Available types: all, atom, vscode, vim, sublime, iterm2, hyper
    \\-i|--input:  The JSON input file to use for generating the themes
    \\             See: https://github.com/benbusby/colorstorm#creating-themes
;

fn parse_args() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    a = arena.allocator();

    var iter = std.process.args();
    var flag: cli.Flag = cli.Flag.na;

    // Skip first arg
    _ = iter.next(a);

    while (iter.next(a)) |arg| {
        const argument = arg catch break;

        if (flag != cli.Flag.na) {
            try cli.set_flag_val(flag, argument);
            flag = cli.Flag.na;
        } else {
            flag = cli.parse_flag(argument);
            if (flag == cli.Flag.help) {
                try stdout.print("\n{s}\n\n", .{help});
                std.os.exit(0);
            }
        }

        // input will always be the last argument, if not
        // explicitly set elsewhere via flag
        if (cli.get_flag_val(cli.Flag.input).?.len == 0) {
            try cli.set_flag_val(cli.Flag.input, argument);
        }

        a.free(argument);
    }
}

pub fn main() !void {
    try cli.init();
    try parse_args();

    var input = cli.get_flag_val(cli.Flag.input).?;
    if (input.len == 0) {
        try stdout.print("ERROR: Missing input file\n{s}\n\n", .{help});
        std.os.exit(1);
    }

    const f = std.fs.cwd().openFile(input, std.fs.File.OpenFlags{ .read = true }) catch {
        try stdout.print("ERROR: Unable to open file '{s}'\n", .{input});
        std.os.exit(1);
    };

    var outdir = cli.get_flag_val(cli.Flag.outdir).?;
    try std.fs.cwd().makePath(cli.get_flag_val(cli.Flag.outdir).?);
    try templator.create_themes(f, outdir, cli.get_flag_val(cli.Flag.gen).?);
}
