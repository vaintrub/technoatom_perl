package DeepClone;
# vim: noet:

use 5.016;
use warnings;
use Devel::FindRef;
# use diagnostics;

=encoding UTF8

=head1 SYNOPSIS

Клонирование сложных структур данных

=head1 clone($orig)

Функция принимает на вход ссылку на какую либо структуру данных и отдаюет, в качестве результата, ее точную независимую копию.
Это значит, что ни один элемент результирующей структуры, не может ссылаться на элементы исходной, но при этом она должна в точности повторять ее схему.

Входные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш Элементами ссылок на массив и хеш, могут быть любые из указанных выше конструкций.
Любые отличные от указанных типы данных -- недопустимы. В этом случае результатом клонирования должен быть undef.

Выходные данные:
* undef
* строка
* число
* ссылка на массив
* ссылка на хеш
Элементами ссылок на массив или хеш, не могут быть ссылки на массивы и хеши исходной структуры данных.

=cut
sub clone;
my %dublicateRef;
sub clone {
	my $orig = shift;
	my $cloned = shift;

	if (my $ref = ref $orig) {
        my $ref2ptr = Devel::FindRef::ref2ptr $orig;
        unless (exists $dublicateRef{$ref2ptr}){
            $dublicateRef{$ref2ptr} = $cloned;
            if ($ref eq 'HASH') {
			    if (!%$orig) {$$cloned = {};}

			    while (my ($k, $v) = each %$orig) {
				    clone($v , \($$cloned->{$k}))
			    }

		    }elsif ($ref eq 'ARRAY') {

			    if ($#$orig) {$$cloned = [];}
			    for (0..$#$orig) {
				    clone($$orig[$_], \($$cloned->[$_]));
			    }   

		    }elsif ($ref eq 'SCALAR') {
			    $$cloned = $orig;
	    	}elsif ($ref eq 'CODE') {
		    	$cloned = \undef;
	    	}elsif ($ref eq 'GLOB') {
		    	$cloned = \undef;
	    	}elsif ($ref eq 'LVALUE') {
	    		$cloned = \undef;
	    	}elsif ($ref eq 'Regexp') {
	    		$cloned = \undef;
	    	}

        }else{
            $$cloned =${$dublicateRef{$ref2ptr}};
        }
		
	}else {

		$$cloned = $orig;

	}


	return $$cloned;
}

1;
