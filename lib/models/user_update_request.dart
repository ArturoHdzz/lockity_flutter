class UserUpdateRequest {
  final String name;
  final String lastName;
  final String secondLastName;

  const UserUpdateRequest({
    required this.name,
    required this.lastName,
    required this.secondLastName,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'last_name': lastName,
      'second_last_name': secondLastName,
    };
  }

  bool get isValid {
    return validationErrors.isEmpty;
  }

  List<String> get validationErrors {
    final errors = <String>[];
    
    if (name.trim().length < 3) {
      errors.add('First name must be at least 3 characters');
    }
    if (lastName.trim().length < 3) {
      errors.add('Last name must be at least 3 characters');
    }
    if (secondLastName.trim().length < 3) {
      errors.add('Second last name must be at least 3 characters');
    }
    
    final nameRegex = RegExp(r"^[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ\s'.-]+$");
    
    if (!nameRegex.hasMatch(name.trim())) {
      errors.add('First name contains invalid characters');
    }
    if (!nameRegex.hasMatch(lastName.trim())) {
      errors.add('Last name contains invalid characters');
    }
    if (!nameRegex.hasMatch(secondLastName.trim())) {
      errors.add('Second last name contains invalid characters');
    }
    
    return errors;
  }

  @override
  String toString() {
    return 'UserUpdateRequest(name: $name, lastName: $lastName, secondLastName: $secondLastName)';
  }
}