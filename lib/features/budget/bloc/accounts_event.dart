part of 'accounts_bloc.dart';

sealed class AccountsEvent extends Equatable {
  const AccountsEvent();

  @override
  List<Object?> get props => [];
}

class AccountsSubscriptionRequested extends AccountsEvent {
  const AccountsSubscriptionRequested();
}

class AccountsListUpdated extends AccountsEvent {
  const AccountsListUpdated(this.accounts);

  final List<AccountModel> accounts;

  @override
  List<Object?> get props => [accounts];
}

class AccountsRefreshRequested extends AccountsEvent {
  const AccountsRefreshRequested();
}

class AccountCreateRequested extends AccountsEvent {
  const AccountCreateRequested({
    required this.name,
    this.type = 'cash',
    this.balance = 0,
    this.color,
  });

  final String name;
  final String type;
  final double balance;
  final String? color;

  @override
  List<Object?> get props => [name, type, balance, color];
}

class AccountUpdateRequested extends AccountsEvent {
  const AccountUpdateRequested(this.account);

  final AccountModel account;

  @override
  List<Object?> get props => [account];
}

class AccountDeleted extends AccountsEvent {
  const AccountDeleted(this.account);

  final AccountModel account;

  @override
  List<Object?> get props => [account];
}
