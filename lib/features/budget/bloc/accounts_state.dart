part of 'accounts_bloc.dart';

enum AccountsStatus { initial, loading, ready }

class AccountsState extends Equatable {
  const AccountsState({
    this.status = AccountsStatus.initial,
    this.accounts = const [],
  });

  final AccountsStatus status;
  final List<AccountModel> accounts;

  double get totalBalance =>
      accounts.fold(0, (sum, account) => sum + account.balance);

  AccountsState copyWith({
    AccountsStatus? status,
    List<AccountModel>? accounts,
  }) => AccountsState(
    status: status ?? this.status,
    accounts: accounts ?? this.accounts,
  );

  @override
  List<Object?> get props => [status, accounts];
}
