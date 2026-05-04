class MalaysianBank {
  final String name;
  final String swiftCode;

  const MalaysianBank({required this.name, required this.swiftCode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MalaysianBank && name == other.name && swiftCode == other.swiftCode;

  @override
  int get hashCode => name.hashCode ^ swiftCode.hashCode;
}

const malaysianBanks = [
  MalaysianBank(name: 'Affin Bank', swiftCode: 'PHBMMYKL'),
  MalaysianBank(name: 'Agrobank', swiftCode: 'AGOBMYKL'),
  MalaysianBank(name: 'Alliance Bank', swiftCode: 'MFBBMYKL'),
  MalaysianBank(name: 'AmBank', swiftCode: 'ARBKMYKL'),
  MalaysianBank(name: 'Bank Islam', swiftCode: 'BIMBMYKL'),
  MalaysianBank(name: 'Bank Muamalat', swiftCode: 'BMMBMYKL'),
  MalaysianBank(name: 'Bank Rakyat', swiftCode: 'BKRMMYKL'),
  MalaysianBank(name: 'Bank Simpanan Nasional', swiftCode: 'BSNAMYK1'),
  MalaysianBank(name: 'Boost Bank', swiftCode: 'BOBEMYK2'),
  MalaysianBank(name: 'CIMB Bank', swiftCode: 'CIBBMYKL'),
  MalaysianBank(name: 'Citibank Malaysia', swiftCode: 'CITIMYKL'),
  MalaysianBank(name: 'GX Bank', swiftCode: 'GXSPMYKL'),
  MalaysianBank(name: 'Hong Leong Bank', swiftCode: 'HLBBMYKL'),
  MalaysianBank(name: 'HSBC Bank Malaysia', swiftCode: 'HBMBMYKL'),
  MalaysianBank(name: 'MBSB Bank', swiftCode: 'AFBQMYKL'),
  MalaysianBank(name: 'Maybank', swiftCode: 'MBBEMYKL'),
  MalaysianBank(name: 'OCBC Bank Malaysia', swiftCode: 'OCBCMYKL'),
  MalaysianBank(name: 'Public Bank', swiftCode: 'PBBEMYKL'),
  MalaysianBank(name: 'RHB Bank', swiftCode: 'RHBBMYKL'),
  MalaysianBank(name: 'Standard Chartered Bank Malaysia', swiftCode: 'SCBLMYKX'),
  MalaysianBank(name: 'UOB Malaysia', swiftCode: 'UOVBMYKL'),
];

const MalaysianBank otherBank = MalaysianBank(name: 'Other', swiftCode: '');