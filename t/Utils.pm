package t::Utils;

use Cwd qw(cwd);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path "$pwd/lib/?.lua;;";
_EOC_

1;
