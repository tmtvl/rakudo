use v6;
# A strftime() subroutine.

module DateTime::strftime {

    multi sub strftime( Str $format is copy, DateTime $dt ) is export(:DEFAULT) {
        my %substitutions =
            # Standard substitutions for yyyy mm dd hh mm ss output.
            'Y' => { $dt.year.fmt(  '%04d') },
            'm' => { $dt.month.fmt( '%02d') },
            'd' => { $dt.day.fmt(   '%02d') },
            'H' => { $dt.hour.fmt(  '%02d') },
            'M' => { $dt.minute.fmt('%02d') },
            'S' => { $dt.whole-second.fmt('%02d') },
            # Special substitutions (Posix-only subset of DateTime or libc)
            'a' => { day-name($dt.day-of-week).substr(0,3) },
            'A' => { day-name($dt.day-of-week) },
            'b' => { month-name($dt.month).substr(0,3) },
            'B' => { month-name($dt.month) },
            'C' => { ($dt.year/100).fmt('%02d') },
            'e' => { $dt.day.fmt('%2d') },
            'F' => { $dt.year.fmt('%04d') ~ '-' ~ $dt.month.fmt(
                     '%02d') ~ '-' ~ $dt.day.fmt('%02d') },
            'I' => { (($dt.hour+23)%12+1).fmt('%02d') },
            'k' => { $dt.hour.fmt('%2d') },
            'l' => { (($dt.hour+23)%12+1).fmt('%2d') },
            'n' => { "\n" },
            'N' => { (($dt.second % 1)*1000000000).fmt('%09d') },
            'p' => { ($dt.hour < 12) ?? 'am' !! 'pm' },
            'P' => { ($dt.hour < 12) ?? 'AM' !! 'PM' },
            'r' => { (($dt.hour+23)%12+1).fmt('%02d') ~ ':' ~
                     $dt.minute.fmt('%02d') ~ ':' ~ $dt.whole-second.fmt('%02d')
                     ~ (($.hour < 12) ?? 'am' !! 'pm') },
            'R' => { $dt.hour.fmt('%02d') ~ ':' ~ $dt.minute.fmt('%02d') },
            's' => { $dt.posix.fmt('%d') },
            't' => { "\t" },
            'T' => { $dt.hour.fmt('%02d') ~ ':' ~ $dt.minute.fmt('%02d') ~ ':' ~ $dt.whole-second.fmt('%02d') },
            'u' => { ~ $dt.day-of-week.fmt('%d') },
            'w' => { ~ (($dt.day-of-week+6) % 7).fmt('%d') },
            'x' => { $dt.year.fmt('%04d') ~ '-' ~ $dt.month.fmt('%02d') ~ '-' ~ $dt.day.fmt('%2d') },
            'X' => { $dt.hour.fmt('%02d') ~ ':' ~ $dt.minute.fmt('%02d') ~ ':' ~ $dt.whole-second.fmt('%02d') },
            'y' => { ($dt.year % 100).fmt('%02d') },
            '%' => { '%' },
            '3' => { (($dt.second % 1)*1000).fmt('%03d') },
            '6' => { (($dt.second % 1)*1000000).fmt('%06d') },
            '9' => { (($dt.second % 1)*1000000000).fmt('%09d') },
            'z' => { $dt.timezone ~~ Callable and die "stftime: Can't use 'z' with Callable time zones.";
                     my $o = $dt.timezone;
                     $o
                       ?? sprintf '%s%02d%02d',
                              $o < 0 ?? '-' !! '+',
                              ($o.abs / 60 / 60).floor,
                              ($o.abs / 60 % 60).floor
                       !! 'Z' }
        ;
        my $result = '';
        while $format ~~ / ^ (<-['%']>*) '%' (.)(.*) $ / {
            unless %substitutions.exists(~$1) { die "unknown strftime format: %$1"; }
            $result ~= $0 ~ %substitutions{~$1}();
            $format = ~$2;
            if $1 eq '3'|'6'|'9' {
                if $format.substr(0,1) ne 'N' { die "strftime format %$1 must be followed by N"; }
                $format = $format.substr(1);
            }
        }
        # The subst for masak++'s nicer-strftime branch is NYI
        # $format .= subst( /'%'(\w|'%')/, { (%substitutions{~$0}
        #            // die "Unknown format letter '\%$0'").() }, :global );
        return $result ~ $format;
    }

    sub day-name($i) {
        # ISO 8601 says Monday is the first day of the week.
        <Monday Tuesday Wednesday Thursday
        Friday Saturday Sunday>[$i - 1]
    }

    sub month-name($i) {
        <January February March April May June July August
        September October November December>[$i - 1]
    }

}

