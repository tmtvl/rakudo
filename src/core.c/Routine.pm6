my class X::Routine::Unwrap { ... }

my role HardRoutine {
    method soft(--> False) { }
}
my role SoftRoutine {
    method soft(--> True) { }
}

my class Routine { # declared in BOOTSTRAP
    # class Routine is Block
    #     has @!dispatchees;
    #     has Mu $!dispatcher_cache;
    #     has Mu $!dispatcher;
    #     has int $!flags;
    #     has Mu $!inline_info;
    #     has Mu $!package;
    #     has int $!onlystar;
    #     has @!dispatch_order;
    #     has Mu $!dispatch_cache;

    method onlystar() { nqp::hllbool($!onlystar) }

    method candidates() {
        self.is_dispatcher ??
            nqp::hllize(@!dispatchees) !!
            (self,)
    }

    method cando(Capture:D $c) {
        my $disp;
        if self.is_dispatcher {
            $disp := self;
        }
        else {
            $disp := nqp::create(self);
            nqp::bindattr($disp, Routine, '@!dispatchees', nqp::list(self));
        }
        # Call this lexical sub to get rid of 'self' in the signature.
        sub checker(|) {
            nqp::hllize($disp.find_best_dispatchee(nqp::usecapture(), 1))
        }
        checker(|$c);
    }

    method multi() {
        self.dispatcher.defined
    }

    multi method gist(Routine:D:) {
        if self.name -> $name {
            "&$name"
        }
        else {
            ( self.^name ~~ m/^\w+/ ).lc ~ ' { }'
        }
    }

    multi method raku(Routine:D:) {
        my $perl = ( self.^name ~~ m/^\w+/ ).lc;
        if self.is_dispatcher {
            $perl = "proto $perl";
        }
        elsif self.multi {
            $perl = "multi $perl";
        }
        if self.name() -> $n {
            $perl ~= " $n";
        }
        my $sig := self.signature.raku;
        $perl ~= " $sig.substr(1)" unless $sig eq ':()';
        $perl ~= self.onlystar
          ?? ' {*}'
          !! self.yada
            ?? ' { ... }'
            !! ' { #`(' ~ self.WHICH ~ ') ... }';
        $perl
    }

    method soft( --> Nil ) { }

    my class WrapHandle {
        has &.wrapper;
        has &.wrappee;

        method restore {
            &.wrappee.unwrap(self)
        }
    }

    method wrap(&wrapper) {
        my $handle = WrapHandle.new: :&wrapper, :wrappee(self);

        if $*W {
            my sub wrapper-fixup() { self!do_wrap(&wrapper) };
            $*W.add_object_if_no_sc(&wrapper);
            $*W.add_object_if_no_sc(&wrapper-fixup);
            $*W.add_fixup_task(
                :deserialize_ast(
                    QAST::Op.new(:op<call>, QAST::WVal.new(:value(&wrapper-fixup)))
                ),
                :fixup_ast(
                    QAST::Op.new(:op<call>, QAST::WVal.new(:value(&wrapper-fixup)))
                ));
        }
        else {
            self!do_wrap(&wrapper);
        }

        $handle
    }

    method !do_wrap(\wrapper) {
        # We can't wrap a hardened routine (that is, one that's been
        # marked inlinable).
        if nqp::istype(self, HardRoutine) {
            die "Cannot wrap a HardRoutine, since it may have been inlined; " ~
                "use the 'soft' pragma to avoid marking routines as hard.";
        }

        if nqp::defined($!wrappers) {
            # Insert next to onlywrap
            nqp::splice($!wrappers, nqp::list(wrapper), 1, 0);
        }
        else {
            my \onlywrap := my sub onlywrap(|) is raw is hidden-from-backtrace {
                $/ := nqp::getlexcaller('$/');
                my Mu $dispatcher := Metamodel::WrapDispatcher.vivify_for(self, nqp::ctx(), nqp::usecapture());
                $dispatcher.call_with_capture(nqp::usecapture())
            };
            my \me = nqp::clone(self);
            if $*W {
                $*W.add_object_if_no_sc(me)
            }
            # Make static code point to the cloned object until original is fully unwrapped. If not done we end up with
            # static code on `me` pointing at the original Routine instance, which has $!do from onlywrap. It results in
            # dispatchers vivified from `me` receive onlywrap as $sub parameter.
            nqp::setcodeobj(nqp::getattr(me, Code, '$!do'), me);
            $!wrappers := nqp::list(onlywrap, wrapper, me);
            my \onlywrap-do := nqp::getattr(onlywrap, Code, '$!do');
            nqp::setcodeobj(onlywrap-do, self);
            nqp::bindattr(self, Code, '$!do', onlywrap-do);
        }
    }

    method unwrap($handle) {
        X::Routine::Unwrap.new.throw unless nqp::istype($handle, WrapHandle);
        my $succeed;
        if $!wrappers {
            my $idx = 0;
            my $count = nqp::elems($!wrappers) - 1;
            my &wrapper := nqp::decont($handle.wrapper);
            while ++$idx < $count {
                my &w := nqp::atpos($!wrappers, $idx);
                if &w === &wrapper {
                    # Also strip off all wrappers put on top of this.
                    nqp::splice($!wrappers, nqp::list(), $idx, 1);
                    $succeed := 1;
                    last;
                }
            }
            if $succeed && $count == 2 {
                # We just have removed the last user wrapper, restore the original code.
                my \orig-do := nqp::getattr(nqp::atpos($!wrappers, 1), Code, '$!do');
                nqp::bindattr(self, Code, '$!do', orig-do);
                nqp::setcodeobj(orig-do, self);
                $!wrappers := nqp::null();
            }
        }
        X::Routine::Unwrap.new.throw unless $succeed;
    }

    method package() { $!package }

    method leave(*@) {
        X::NYI.new(:feature("{self.^name}.leave()")).throw;
    }
}

# vim: ft=perl6 expandtab sw=4
