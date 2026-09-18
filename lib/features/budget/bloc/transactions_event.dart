part of 'transactions_bloc.dart';

sealed class TransactionsEvent extends Equatable {
  const TransactionsEvent();

  @override
  List<Object?> get props => [];
}

class TransactionsSubscriptionRequested extends TransactionsEvent {
  const TransactionsSubscriptionRequested();
}

class TransactionsListUpdated extends TransactionsEvent {
  const TransactionsListUpdated(this.transactions);

  final List<TransactionModel> transactions;

  @override
  List<Object?> get props => [transactions];
}

class TransactionsRefreshRequested extends TransactionsEvent {
  const TransactionsRefreshRequested();
}

class TransactionCreateRequested extends TransactionsEvent {
  const TransactionCreateRequested({
    required this.accountLocalUuid,
    this.destinationAccountLocalUuid,
    this.categoryLocalUuid,
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.description,
  });

  final String accountLocalUuid;
  final String? destinationAccountLocalUuid;
  final String? categoryLocalUuid;
  final String type;
  final double amount;
  final DateTime occurredAt;
  final String? description;

  @override
  List<Object?> get props => [
    accountLocalUuid,
    destinationAccountLocalUuid,
    categoryLocalUuid,
    type,
    amount,
    occurredAt,
    description,
  ];
}

class TransactionUpdateRequested extends TransactionsEvent {
  const TransactionUpdateRequested(this.transaction);

  final TransactionModel transaction;

  @override
  List<Object?> get props => [transaction];
}

class TransactionDeleted extends TransactionsEvent {
  const TransactionDeleted(this.transaction);

  final TransactionModel transaction;

  @override
  List<Object?> get props => [transaction];
}
