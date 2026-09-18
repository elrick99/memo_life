import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/transaction_model.dart';
import '../data/transaction_repository.dart';

part 'transactions_event.dart';
part 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  TransactionsBloc({required this._repository})
    : super(const TransactionsState()) {
    on<TransactionsSubscriptionRequested>(_onSubscriptionRequested);
    on<TransactionsListUpdated>(_onListUpdated);
    on<TransactionsRefreshRequested>(_onRefreshRequested);
    on<TransactionCreateRequested>(_onCreateRequested);
    on<TransactionUpdateRequested>(_onUpdateRequested);
    on<TransactionDeleted>(_onDeleted);
  }

  final TransactionRepository _repository;
  StreamSubscription<void>? _changesSubscription;

  Future<void> _onSubscriptionRequested(
    TransactionsSubscriptionRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(state.copyWith(status: TransactionsStatus.loading));
    await _changesSubscription?.cancel();
    _changesSubscription = _repository.changes.listen((_) async {
      add(TransactionsListUpdated(await _repository.getTransactions()));
    });
    emit(
      state.copyWith(
        status: TransactionsStatus.ready,
        transactions: await _repository.getTransactions(),
      ),
    );
  }

  void _onListUpdated(
    TransactionsListUpdated event,
    Emitter<TransactionsState> emit,
  ) {
    emit(
      state.copyWith(
        status: TransactionsStatus.ready,
        transactions: event.transactions,
      ),
    );
  }

  Future<void> _onRefreshRequested(
    TransactionsRefreshRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    await _repository.pull();
  }

  Future<void> _onCreateRequested(
    TransactionCreateRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    await _repository.createTransaction(
      accountLocalUuid: event.accountLocalUuid,
      destinationAccountLocalUuid: event.destinationAccountLocalUuid,
      categoryLocalUuid: event.categoryLocalUuid,
      type: event.type,
      amount: event.amount,
      occurredAt: event.occurredAt,
      description: event.description,
    );
  }

  Future<void> _onUpdateRequested(
    TransactionUpdateRequested event,
    Emitter<TransactionsState> emit,
  ) async {
    await _repository.updateTransaction(event.transaction);
  }

  Future<void> _onDeleted(
    TransactionDeleted event,
    Emitter<TransactionsState> emit,
  ) async {
    await _repository.deleteTransaction(event.transaction);
  }

  @override
  Future<void> close() {
    unawaited(_changesSubscription?.cancel());

    return super.close();
  }
}
