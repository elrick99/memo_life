import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/account_model.dart';
import '../data/account_repository.dart';

part 'accounts_event.dart';
part 'accounts_state.dart';

class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  AccountsBloc({required this._repository}) : super(const AccountsState()) {
    on<AccountsSubscriptionRequested>(_onSubscriptionRequested);
    on<AccountsListUpdated>(_onListUpdated);
    on<AccountsRefreshRequested>(_onRefreshRequested);
    on<AccountCreateRequested>(_onCreateRequested);
    on<AccountUpdateRequested>(_onUpdateRequested);
    on<AccountDeleted>(_onDeleted);
  }

  final AccountRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    AccountsSubscriptionRequested event,
    Emitter<AccountsState> emit,
  ) async {
    emit(state.copyWith(status: AccountsStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(AccountsListUpdated(await _repository.getAccounts()));
    });
    emit(
      state.copyWith(
        status: AccountsStatus.ready,
        accounts: await _repository.getAccounts(),
      ),
    );
  }

  void _onListUpdated(AccountsListUpdated event, Emitter<AccountsState> emit) {
    emit(
      state.copyWith(status: AccountsStatus.ready, accounts: event.accounts),
    );
  }

  Future<void> _onRefreshRequested(
    AccountsRefreshRequested event,
    Emitter<AccountsState> emit,
  ) async {
    await _repository.pull();
  }

  Future<void> _onCreateRequested(
    AccountCreateRequested event,
    Emitter<AccountsState> emit,
  ) async {
    await _repository.createAccount(
      name: event.name,
      type: event.type,
      balance: event.balance,
      color: event.color,
    );
  }

  Future<void> _onUpdateRequested(
    AccountUpdateRequested event,
    Emitter<AccountsState> emit,
  ) async {
    await _repository.updateAccount(event.account);
  }

  Future<void> _onDeleted(
    AccountDeleted event,
    Emitter<AccountsState> emit,
  ) async {
    await _repository.deleteAccount(event.account);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
