/// PEP (Politically Exposed Person) declaration data model.
enum PepRelationship { self, familyMember, closeAssociate }

extension PepRelationshipX on PepRelationship {
  String get keyword => switch (this) {
        PepRelationship.self => 'SELF',
        PepRelationship.familyMember => 'FAMILY',
        PepRelationship.closeAssociate => 'ASSOCIATE',
      };

  String get label => switch (this) {
        PepRelationship.self => 'Self',
        PepRelationship.familyMember => 'Immediate Family Member',
        PepRelationship.closeAssociate => 'Close Associate',
      };
}

class PepDeclarationData {
  bool isPep;
  PepRelationship? relationship;
  String? name;
  String? position;
  String? organisation;
  String? supportingDocKey;

  PepDeclarationData({
    this.isPep = false,
    this.relationship,
    this.name,
    this.position,
    this.organisation,
    this.supportingDocKey,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'is_pep': isPep,
    };
    if (isPep && relationship != null) {
      map['pep_relationship'] = relationship!.keyword;
      map['pep_name'] = name;
      map['pep_position'] = position;
      map['pep_organisation'] = organisation;
      map['pep_supporting_doc_key'] = supportingDocKey;
    }
    return map;
  }
}