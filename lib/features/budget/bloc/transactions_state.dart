part of 'transactions_bloc.dart';

enum TransactionsStatus { initial, loading, ready }

class TransactionsState extends Equatable {
  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
  });

  final TransactionsStatus status;
  final List<TransactionModel> transactions;

  TransactionsState copyWith({
    TransactionsStatus? status,
    List<TransactionModel>? transactions,
  }) => TransactionsState(
    status: status ?? this.status,
    transactions: transactions ?? this.transactions,
  );

  @override
  List<Object?> get props => [status, transactions];
}
