# IAM users

## Variables

### "superadmin_users"
Creates a number of users with superadmin access level

### "users"
For usual users.

We can add a number of variables with corresponding resources to have a number of users with different privileges.

This module creates users with programmatic access and with passwords if it needs. To create a user with password needs to use PGP private and public key. It requires by Amazon. Terraform will output an encrypted passwords which we can decrypt by private PGP key.

*Steps in module.*
1. Create an users
2. Create Policy
3. Create a group
4. Attach this policy to group
5. Add an user to this group.
