part of 'package:web3dart/web3dart.dart';

enum TransactionType {
  legacy,
  valueTransfer,
  feeDelegatedValueTransfer,
  valueTransferMemo,
  feeDelegatedValueTransferMemo,
  smartContractDeploy,
  feeDelegatedSmartContractDeploy,
  smartContractExecution,
  feeDelegatedSmartContractExecution,
  accountUpdate,
  feeDelegatedAccountUpdate,
  cancel,
  feeDelegatedCancel,
}

int transactionTypeToInt(TransactionType type) {
  switch (type) {
    case TransactionType.legacy:
      return 0x0;
    case TransactionType.valueTransfer:
      return 0x8;
    case TransactionType.feeDelegatedValueTransfer:
      return 0x9;
    case TransactionType.valueTransferMemo:
      return 0x10;
    case TransactionType.feeDelegatedValueTransferMemo:
      return 0x11;
    case TransactionType.accountUpdate:
      return 0x20;
    case TransactionType.feeDelegatedAccountUpdate:
      return 0x21;
    case TransactionType.smartContractDeploy:
      return 0x28;
    case TransactionType.feeDelegatedSmartContractDeploy:
      return 0x29;
    case TransactionType.smartContractExecution:
      return 0x30;
    case TransactionType.feeDelegatedSmartContractExecution:
      return 0x31;
    case TransactionType.cancel:
      return 0x38;
    case TransactionType.feeDelegatedCancel:
      return 0x39;
  }
}

Future<Uint8List> _encodeToRlpForSignature(TransactionType type,
    Transaction transaction, int? chainId, Credentials c) async {
  if (type == TransactionType.legacy) {
    final innerSignature = chainId == null
        ? null
        : MsgSignature(BigInt.zero, BigInt.zero, chainId);
    final encoded = _encodeToRlp(transaction, innerSignature);
    return uint8ListFromList(rlp.encode(encoded));
  }

  final list = [];
  var innerList = [];
  switch (type) {
    case TransactionType.legacy:
      throw UnsupportedError('unreachable code');
    case TransactionType.valueTransfer:
      innerList = await rlpForSigOfValueTransfer(type, transaction, c);
      break;
    case TransactionType.smartContractExecution:
      innerList = await rlpForSigOfSmartContractExecution(type, transaction, c);
      break;
    case TransactionType.valueTransferMemo:
    case TransactionType.smartContractDeploy:
    case TransactionType.cancel:
      throw UnimplementedError();

    case TransactionType.feeDelegatedValueTransfer:
    case TransactionType.feeDelegatedValueTransferMemo:
    case TransactionType.feeDelegatedSmartContractDeploy:
    case TransactionType.feeDelegatedSmartContractExecution:
    case TransactionType.accountUpdate:
    case TransactionType.feeDelegatedAccountUpdate:
    case TransactionType.feeDelegatedCancel:
      throw UnimplementedError();
  }

  final encodedInnerList = uint8ListFromList(rlp.encode(innerList));
  list
    ..add(encodedInnerList)
    ..add(chainId)
    ..add(0)
    ..add(0);

  return uint8ListFromList(rlp.encode(list));
}

List<dynamic> fillCommonData(TransactionType type, Transaction transaction) {
  final list = [];
  list
    ..add(transactionTypeToInt(type))
    ..add(transaction.nonce)
    ..add(transaction.gasPrice!.getInWei)
    ..add(transaction.maxGas);
  return list;
}

Future<List> rlpForSigOfValueTransfer(
    TransactionType type, Transaction transaction, Credentials c) async {
  final list = fillCommonData(type, transaction);

  if (transaction.to != null) {
    list.add(transaction.to!.addressBytes);
  } else {
    list.add('');
  }

  list
    ..add(transaction.value?.getInWei)
    ..add((await c.extractAddress()).addressBytes);

  return list;
}

Future<List> rlpForSigOfSmartContractExecution(
    TransactionType type, Transaction transaction, Credentials c) async {
  final list = fillCommonData(type, transaction);

  if (transaction.to != null) {
    list.add(transaction.to!.addressBytes);
  } else {
    list.add('');
  }

  list
    ..add(transaction.value?.getInWei)
    ..add((await c.extractAddress()).addressBytes)
    ..add(transaction.data);

  return list;
}

Future<Uint8List> _encodeToRlpForTransaction(TransactionType type,
    Transaction transaction, Credentials c, List<MsgSignature> sig) async {
  if (type == TransactionType.legacy) {
    return uint8ListFromList(rlp.encode(_encodeToRlp(transaction, sig.first)));
  }

  final typeInt = transactionTypeToInt(type);

  final List list;
  switch (type) {
    case TransactionType.legacy:
      throw UnsupportedError('unreachable code');
    case TransactionType.valueTransfer:
    case TransactionType.valueTransferMemo:
    case TransactionType.smartContractExecution:
    case TransactionType.smartContractDeploy:
      list = await rlpForTx(type, transaction, c);
      break;
    case TransactionType.accountUpdate:
    case TransactionType.cancel:
      throw UnimplementedError();

    case TransactionType.feeDelegatedValueTransfer:
    case TransactionType.feeDelegatedValueTransferMemo:
    case TransactionType.feeDelegatedSmartContractDeploy:
    case TransactionType.feeDelegatedSmartContractExecution:
    case TransactionType.feeDelegatedAccountUpdate:
    case TransactionType.feeDelegatedCancel:
      throw UnimplementedError();
  }
  list.add(encodeTxSignature(sig));

  final result = <int>[];
  result.add(typeInt);
  result.addAll(uint8ListFromList(rlp.encode(list)));
  return Uint8List.fromList(result);
}

Future<List<dynamic>> rlpForTx(
    TransactionType type, Transaction transaction, Credentials c) async {
  final list = [];
  list
    ..add(transaction.nonce)
    ..add(transaction.gasPrice!.getInWei)
    ..add(transaction.maxGas)
    ..add(transaction.to!.addressBytes)
    ..add(transaction.value?.getInWei)
    ..add((await c.extractAddress()).addressBytes);

  if ([
    TransactionType.valueTransferMemo,
    TransactionType.smartContractExecution,
    TransactionType.smartContractDeploy,
  ].contains(type)) {
    list.add(transaction.data);
  }

  if (type == TransactionType.smartContractDeploy) {
    list
      ..add(false)
      ..add(0x00);
  }

  return list;
}

Future<List<dynamic>> rlpForTxForSmartContractExecution(
    Transaction transaction, Credentials c) async {
  final list = [];
  list
    ..add(transaction.nonce)
    ..add(transaction.gasPrice!.getInWei)
    ..add(transaction.maxGas)
    ..add(transaction.to!.addressBytes)
    ..add(transaction.value?.getInWei)
    ..add((await c.extractAddress()).addressBytes);
  return list;
}

List encodeTxSignature(List<MsgSignature> signatures) {
  final list = [];

  for (final sig in signatures) {
    list.add([sig.v, sig.r, sig.s]);
  }

  return list;
}
