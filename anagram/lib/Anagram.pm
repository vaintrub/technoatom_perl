package Anagram;
# vim: noet:

use 5.016;
use warnings;
use utf8;
use Data::Dumper;
use List::MoreUtils qw(uniq);
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';

=encoding UTF8

=head1 SYNOPSIS

Поиск анаграмм

=head1 anagram($arrayref)

Функция поиска всех множеств анаграмм по словарю.

Входные данные для функции: ссылка на массив - каждый элемент которого - слово на русском языке в кодировке utf8

Выходные данные: Ссылка на хеш множеств анаграмм.

Ключ - первое встретившееся в словаре слово из множества
Значение - ссылка на массив, каждый элемент которого слово из множества, в том порядке в котором оно встретилось в словаре в первый раз.

Множества из одного элемента не должны попасть в результат.

Все слова должны быть приведены к нижнему регистру.
В результирующем множестве каждое слово должно встречаться только один раз.
Например

anagram(['пятак', 'ЛиСток', 'пятка', 'стул', 'ПяТаК', 'слиток', 'тяпка', 'столик', 'слиток'])

должен вернуть ссылку на хеш


{
	'пятак'  => ['пятак', 'пятка', 'тяпка'],
	'листок' => ['листок', 'слиток', 'столик'],
}

=cut

sub anagram {
	my $words_list = shift;



	my %result;
	my $letters;

	for my $word (@$words_list) {
		$word = lc $word;
		$letters = join ('',sort split(//,$word));
		if (exists $result{$letters}){
			push @{$result{$letters}{'_words'}}, $word;
		}else{
			$result{$letters}{'_first'} = $word;
			push @{$result{$letters}{'_words'}}, $word;
		}
	}

	my %result_end;
	while (my ($k,$v) = each %result) {
		@{$result{$k}{'_words'}} = uniq @{$result{$k}{'_words'}}; # delete the same words

		if (@{$result{$k}{'_words'}} != 1) {
			$result_end{$result{$k}{'_first'}} = [sort(@{$result{$k}{'_words'}})];
		}
	}
	return \%result_end;
}

1;
