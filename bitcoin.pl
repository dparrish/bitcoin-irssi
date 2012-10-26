#!/usr/bin/perl -w

use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0.1";

%IRSSI = (
  authors     => 'David Parrish',
  contact     => 'david@dparrish.com',
  name        => 'bitcoin.pl',
  description => 'Helpers for accessing bitcoind functions.',
  license     => 'GNU General Public License',
  url         => 'http://sites.dparrish.com/bitcoin-irssi',
  changed     => 'Fri Oct 26 11:23:00 AEST 2012',
);

my $bitcoind = '/usr/bin/bitcoind';

# This setting controls whether this plugin (and irssi) is allowed to send bitcoins.
# The default is to disallow the bc send command. Chanage this to 1 to allow it.
my $allow_send = 0;

my $help = <<EOF;

Usage: (all on one line)
/BITCOIN [bal[ance] [account]]
         [send <address> <amount> [comment]]
         [addr[ess] [account] [send]]

balance:    Return either the overall balance of the wallet, or a specified account.
send:       Send the given amount of bitcoins to the address provided, with an optional comment.
address:    Returns a bitcoin address specific to the current window, or a specified account.
            This creates a new account for each channel or person the first
            time this is called, and a new address after bitcoins have been
            received by that address.
            If an account is specified (or _ for the current window) and "send"
            is not empty, the address will be sent to the current window
            instead of printed.
help:       Display this useful little helptext.

Examples: (all on one line)
/q dparrish
/bitcoin addr
/bc send 1DpArrisH3Z1go6E13K75CNhUKvFtARgLd 1 Donation

Note: Both /BITCOIN and /BC are valid commands.
EOF

Irssi::theme_register([
  'bitcoin_total_balance', '%R>>%n %_Bitcoin:%_ Total Bitcoin balance: $0',
  'bitcoin_account_balance', '%R>>%n %_Bitcoin:%_ Bitcoin balance for "$0": $1',
  'bitcoin_usage', '%R>>%n %_Bitcoin:%_ Insufficient parameters: Use "%_/BITCOIN help%_" for further instructions.',
  'bitcoin_help', '$0',
  'bitcoin_output', '%R>>%n %_Bitcoin:%_: $0',
  'bitcoin_address', '%R>>%n %_Bitcoin%_: Address for $0:%_: $1',
  'bitcoin_loaded', '%R>>%n %_Bitcoin:%_ Loaded $0 version $1 by $2 <$3>.'
]);

sub bitcoind(@) {
  open(BITCOIN, "-|", 'bitcoind', @_);
  chomp(my @output = <BITCOIN>);
  close BITCOIN;
  return @output;
}

sub bitcoin_balance {
  my($data, $server, $item) = @_;
  $data =~ s/\s+$//g;
  my $account = $data;
  if (!$account) {
    my($balance) = bitcoind("getbalance");
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_total_balance', $balance);
    return;
  }

  if ($account eq "_") {
    if ($item->{type} eq 'QUERY') {
      $account = $item->{visible_name};
    } elsif ($item->{type} eq 'CHANNEL') {
      $account = $item->{visible_name};
    } else {
      Irssi::print("Unknown window type $item->{type}");
      return;
    }
  }

  my($balance) = bitcoind("getbalance", $account);
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_account_balance', $account, $balance);
}

sub bitcoin_address {
  my($data, $server, $item) = @_;
  my($account, $send) = split(/\s+/, $data, 2);

  if (!$account || $account eq "_") {
    if ($item->{type} eq 'QUERY' || $item->{type} eq 'CHANNEL') {
      $account = $item->{visible_name};
    } else {
      Irssi::print("Unknown window type $item->{type}");
      return;
    }
  }

  my($address) = bitcoind("getaccountaddress", $account);
  if ($send) {
    $item->command("MSG $item->{name} $address");
  } else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_address', $account, $address);
  }
}

sub bitcoin_send {
  my($data, $server, $item) = @_;
  $data =~ s/\s+$//g;
  my($address, $amount, $comment) = split(/\s+/, $data, 3);

  if (!$allow_send) {
    Irssi::print("Sending of bitcoins is disabled. Change the \$allow_send flag in the plugin code to enable it.");
    return;
  }

  if (!$address || !$amount) {
    Irssi::print("Usage: /bc send <address> <amount> [comment]");
    return;
  }

  if ($amount !~ /^\d+(?:\.\d+)?$/) {
    Irssi::print("Invalid amount $amount");
    Irssi::print("Usage: /bc send <address> <amount> [comment]");
    return;
  }

  my @output = bitcoind("sendtoaddress", $address, $amount, $comment);
  for my $line (@output) {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_output', $line);
  }
}

sub bitcoin_runsub {
  my ($data, $server, $item) = @_;
  $data =~ s/\s+$//g;

  if ($data) {
    Irssi::command_runsub('bitcoin', $data, $server, $item);
  } else {
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_usage');
  }
}

Irssi::command_bind('bitcoin', 'bitcoin_runsub');
Irssi::command_bind('bc', 'bitcoin_runsub');
Irssi::command_bind('bitcoin bal', 'bitcoin_balance');
Irssi::command_bind('bc bal', 'bitcoin_balance');
Irssi::command_bind('bitcoin balance', 'bitcoin_balance');
Irssi::command_bind('bc balance', 'bitcoin_balance');
Irssi::command_bind('bitcoin addr', 'bitcoin_address');
Irssi::command_bind('bc addr', 'bitcoin_address');
Irssi::command_bind('bitcoin address', 'bitcoin_address');
Irssi::command_bind('bc address', 'bitcoin_address');
Irssi::command_bind('bitcoin send', 'bitcoin_send');
Irssi::command_bind('bc send', 'bitcoin_send');

Irssi::command_bind('bitcoin help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_help', $help) });
Irssi::command_bind('bc help' => sub { Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_help', $help) });

Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'bitcoin_loaded', $IRSSI{name}, $VERSION, $IRSSI{authors}, $IRSSI{contact});
