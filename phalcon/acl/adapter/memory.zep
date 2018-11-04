
/*
 +------------------------------------------------------------------------+
 | Phalcon Framework                                                      |
 +------------------------------------------------------------------------+
 | Copyright (c) 2011-2017 Phalcon Team (https://phalconphp.com)          |
 +------------------------------------------------------------------------+
 | This source file is subject to the New BSD License that is bundled     |
 | with this package in the file LICENSE.txt.                             |
 |                                                                        |
 | If you did not receive a copy of the license and are unable to         |
 | obtain it through the world-wide-web, please send an email             |
 | to license@phalconphp.com so we can send you a copy immediately.       |
 +------------------------------------------------------------------------+
 | Authors: Andres Gutierrez <andres@phalconphp.com>                      |
 |          Eduar Carvajal <eduar@phalconphp.com>                         |
 +------------------------------------------------------------------------+
 */

namespace Phalcon\Acl\Adapter;

use Phalcon\Acl;
use Phalcon\Acl\Adapter;
use Phalcon\Acl\Role;
use Phalcon\Acl\RoleInterface;
use Phalcon\Acl\Resource;
use Phalcon\Acl\Exception;
use Phalcon\Events\Manager as EventsManager;
use Phalcon\Acl\RoleAware;
use Phalcon\Acl\ResourceAware;
use Phalcon\Acl\RoleInterface;
use Phalcon\Acl\ResourceInterface;

/**
 * Phalcon\Acl\Adapter\Memory
 *
 * Manages ACL lists in memory
 *
 *<code>
 * $acl = new \Phalcon\Acl\Adapter\Memory();
 *
 * $acl->setDefaultAction(
 *     \Phalcon\Acl::DENY
 * );
 *
 * // Register roles
 * $roles = [
 *     "users"  => new \Phalcon\Acl\Role("Users"),
 *     "guests" => new \Phalcon\Acl\Role("Guests"),
 * ];
 * foreach ($roles as $role) {
 *     $acl->addRole($role);
 * }
 *
 * // Private area resources
 * $privateResources = [
 *     "companies" => ["index", "search", "new", "edit", "save", "create", "delete"],
 *     "products"  => ["index", "search", "new", "edit", "save", "create", "delete"],
 *     "invoices"  => ["index", "profile"],
 * ];
 *
 * foreach ($privateResources as $resourceName => $actions) {
 *     $acl->addResource(
 *         new \Phalcon\Acl\Resource($resourceName),
 *         $actions
 *     );
 * }
 *
 * // Public area resources
 * $publicResources = [
 *     "index"   => ["index"],
 *     "about"   => ["index"],
 *     "session" => ["index", "register", "start", "end"],
 *     "contact" => ["index", "send"],
 * ];
 *
 * foreach ($publicResources as $resourceName => $actions) {
 *     $acl->addResource(
 *         new \Phalcon\Acl\Resource($resourceName),
 *         $actions
 *     );
 * }
 *
 * // Grant access to public areas to both users and guests
 * foreach ($roles as $role){
 *     foreach ($publicResources as $resource => $actions) {
 *         $acl->allow($role->getName(), $resource, "*");
 *     }
 * }
 *
 * // Grant access to private area to role Users
 * foreach ($privateResources as $resource => $actions) {
 *     foreach ($actions as $action) {
 *         $acl->allow("Users", $resource, $action);
 *     }
 * }
 *</code>
 */
class Memory extends Adapter
{

	/**
	 * Roles Names
	 *
	 * @var mixed
	 */
	protected _rolesNames;

	/**
	 * Roles
	 *
	 * @var mixed
	 */
	protected _roles;

	/**
	 * Resource Names
	 *
	 * @var mixed
	 */
	protected _resourcesNames;

	/**
	 * Resources
	 *
	 * @var mixed
	 */
	protected _resources;

	/**
	 * Access
	 *
	 * @var mixed
	 */
	protected _access;

	/**
	 * Role Inherits
	 *
	 * @var mixed
	 */
	protected _roleInherits;

	/**
	 * Access List
	 *
	 * @var mixed
	 */
	protected _accessList;

	/**
	 * Function List
	 *
	 * @var mixed
	 */
	protected _func;

	/**
	 * Default action for no arguments is allow
	 *
	 * @var mixed
	 */
	protected _noArgumentsDefaultAction = Acl::ALLOW;

	/**
	 * Phalcon\Acl\Adapter\Memory constructor
	 */
	public function __construct()
	{
		let this->_resourcesNames = ["*": true];
		let this->_accessList = ["*!*": true];
	}

	/**
	 * Adds a role to the ACL list. Second parameter allows inheriting access data from other existing role
	 *
	 * Example:
	 * <code>
	 * $acl->addRole(
	 *     new Phalcon\Acl\Role("administrator"),
	 *     "consultant"
	 * );
	 *
	 * $acl->addRole("administrator", "consultant");
	 * $acl->addRole("administrator", ["consultant", "consultant2"]);
	 * </code>
	 *
	 * @param  array|string         accessInherits
	 * @param  RoleInterface|string|array role
	 */
	public function addRole(role, accessInherits = null) -> boolean
	{
		var roleName, roleObject;

		if typeof role == "object" && role instanceof RoleInterface {
			let roleName = role->getName();
			let roleObject = role;
		} elseif is_string(role) {
			let roleName = role;
			let roleObject = new Role(role);
		} else {
			throw new Exception("Role must be either an string or implement RoleInterface");
		}

		if isset this->_rolesNames[roleName] {
			return false;
		}

		let this->_roles[] = roleObject;
		let this->_rolesNames[roleName] = true;

		if accessInherits != null {
			return this->addInherit(roleName, accessInherits);
		}

		return true;
	}

	/**
     * Do a role inherit from another existing role
     *
     * Example:
     * <code>
     *
     * $acl->addRole("administrator", "consultant");
     * $acl->addRole("administrator", ["consultant", "consultant2"]);
     * </code>
     *
     * @param  array|string         accessInherits
     * @param  RoleInterface|string|array role
     */
	public function addInherit(string roleName, var roleToInherits) -> boolean
	{
		var roleInheritName, rolesNames, deepInheritName, roleToInherit, checkRoleToInherit,
		 checkRoleToInherits, usedRoleToInherits, roleToInheritList, usedRoleToInherit;

		let rolesNames = this->_rolesNames;
		if !isset rolesNames[roleName] {
			throw new Exception("Role '" . roleName . "' does not exist in the role list");
		}

		if !isset this->_roleInherits[roleName] {
            let this->_roleInherits[roleName] = [];
        }
		/**
		 * Type conversion
         */
        if typeof roleToInherits != "array" {
            let roleToInheritList = [roleToInherits];
        }else{
            let roleToInheritList = roleToInherits;
        }
        /**
         * inherits
         */
        for roleToInherit in roleToInheritList {
            if typeof roleToInherit == "object" && roleToInherit instanceof RoleInterface {
                let roleInheritName = roleToInherit->getName();
            } else {
                let roleInheritName = roleToInherit;
            }
            /**
             * Check if the role to inherit is repeat
             */
            if in_array(roleInheritName, this->_roleInherits[roleName]) {
                continue;
            }
            /**
             * Check if the role to inherit is valid
             */
            if !isset rolesNames[roleInheritName] {
                throw new Exception("Role '" . roleInheritName . "' (to inherit) does not exist in the role list");
            }

            if roleName == roleInheritName {
                return false;
            }
            /**
             * Deep check if the role to inherit is valid
             */
            if isset this->_roleInherits[roleInheritName] {
                let checkRoleToInherits = [];
                for usedRoleToInherit in this->_roleInherits[roleInheritName] {
                    let checkRoleToInherits[] = usedRoleToInherit;
                }
                let usedRoleToInherits = [];
                while !empty checkRoleToInherits {
                    let checkRoleToInherit = array_shift(checkRoleToInherits);
                    
                    if isset usedRoleToInherits[checkRoleToInherit] {
                        continue;
                    }
                    let usedRoleToInherits[checkRoleToInherit] = true;
                    if roleName == checkRoleToInherit {
                        throw new Exception("Role '" . roleInheritName . "' (to inherit) is infinite loop ");
                    }
                    /**
                     * Push inherited roles
                     */
                    if isset this->_roleInherits[checkRoleToInherit] {
                        for usedRoleToInherit in this->_roleInherits[checkRoleToInherit] {
                            let checkRoleToInherits[] = usedRoleToInherit;
                        }
                    }
                }
            }

            let this->_roleInherits[roleName][] = roleInheritName;
        }
		return true;
	}

	/**
	 * Check whether role exist in the roles list
	 */
	public function isRole(string roleName) -> boolean
	{
		return isset this->_rolesNames[roleName];
	}

	/**
	 * Check whether resource exist in the resources list
	 */
	public function isResource(string resourceName) -> boolean
	{
		return isset this->_resourcesNames[resourceName];
	}

	/**
	 * Adds a resource to the ACL list
	 *
	 * Access names can be a particular action, by example
	 * search, update, delete, etc or a list of them
	 *
	 * Example:
	 * <code>
	 * // Add a resource to the the list allowing access to an action
	 * $acl->addResource(
	 *     new Phalcon\Acl\Resource("customers"),
	 *     "search"
	 * );
	 *
	 * $acl->addResource("customers", "search");
	 *
	 * // Add a resource  with an access list
	 * $acl->addResource(
	 *     new Phalcon\Acl\Resource("customers"),
	 *     [
	 *         "create",
	 *         "search",
	 *     ]
	 * );
	 *
	 * $acl->addResource(
	 *     "customers",
	 *     [
	 *         "create",
	 *         "search",
	 *     ]
	 * );
	 * </code>
	 *
	 * @param   Phalcon\Acl\Resource|string resourceValue
	 * @param   array|string accessList
	 */
	public function addResource(var resourceValue, var accessList) -> boolean
	{
		var resourceName, resourceObject;

		if typeof resourceValue == "object" && resourceValue instanceof ResourceInterface {
			let resourceName   = resourceValue->getName();
			let resourceObject = resourceValue;
		 } else {
			let resourceName   = resourceValue;
			let resourceObject = new $Resource(resourceName);
		 }

		 if !isset this->_resourcesNames[resourceName] {
			let this->_resources[] = resourceObject;
			let this->_resourcesNames[resourceName] = true;
		 }

		 return this->addResourceAccess(resourceName, accessList);
	}

	/**
	 * Adds access to resources
	 *
	 * @param array|string accessList
	 */
	public function addResourceAccess(string resourceName, var accessList) -> boolean
	{
		var accessName, accessKey, exists;

		if !isset this->_resourcesNames[resourceName] {
			throw new Exception("Resource '" . resourceName . "' does not exist in ACL");
		}

		if typeof accessList != "array" && typeof accessList != "string" {
			throw new Exception("Invalid value for accessList");
		}

		let exists = true;
		if typeof accessList == "array" {
			for accessName in accessList {
				let accessKey = resourceName . "!" . accessName;
				if !isset this->_accessList[accessKey] {
					let this->_accessList[accessKey] = exists;
				}
			}
		} else {
			let accessKey = resourceName . "!" . accessList;
			if !isset this->_accessList[accessKey] {
				let this->_accessList[accessKey] = exists;
			}
		}

		return true;
	}

	/**
	 * Removes an access from a resource
	 *
	 * @param array|string accessList
	 */
	public function dropResourceAccess(string resourceName, var accessList)
	{
		var accessName, accessKey;

		if typeof accessList == "array" {
			for accessName in accessList {
				let accessKey = resourceName . "!" . accessName;
				if isset this->_accessList[accessKey] {
					unset this->_accessList[accessKey];
				}
			}
		} else {
			if typeof accessList == "string" {
				let accessKey = resourceName . "!" . accessName;
				if isset this->_accessList[accessKey] {
					unset this->_accessList[accessKey];
				}
			}
		}
	 }

	/**
	 * Checks if a role has access to a resource
	 */
	protected function _allowOrDeny(string roleName, string resourceName, var access, var action, var func = null)
	{
		var accessList, accessName, accessKey;

		if !isset this->_rolesNames[roleName] {
			throw new Exception("Role '" . roleName . "' does not exist in ACL");
		}

		if !isset this->_resourcesNames[resourceName] {
			throw new Exception("Resource '" . resourceName . "' does not exist in ACL");
		}

		let accessList = this->_accessList;

		if typeof access == "array" {

			for accessName in access {
				let accessKey = resourceName . "!" . accessName;
				if !isset accessList[accessKey] {
					throw new Exception("Access '" . accessName . "' does not exist in resource '" . resourceName . "'");
				}
			}

			for accessName in access {

				let accessKey = roleName . "!" .resourceName . "!" . accessName;
				let this->_access[accessKey] = action;
				if func != null {
				    let this->_func[accessKey] = func;
				}
			}

		} else {

			if access != "*" {
				let accessKey = resourceName . "!" . access;
				if !isset accessList[accessKey] {
					throw new Exception("Access '" . access . "' does not exist in resource '" . resourceName . "'");
				}
			}

			let accessKey = roleName . "!" . resourceName . "!" . access;

			/**
			 * Define the access action for the specified accessKey
			 */
			let this->_access[accessKey] = action;
			if func != null {
				let this->_func[accessKey] = func;
			}

		}
	}

	/**
	 * Allow access to a role on a resource
	 *
	 * You can use '*' as wildcard
	 *
	 * Example:
	 * <code>
	 * //Allow access to guests to search on customers
	 * $acl->allow("guests", "customers", "search");
	 *
	 * //Allow access to guests to search or create on customers
	 * $acl->allow("guests", "customers", ["search", "create"]);
	 *
	 * //Allow access to any role to browse on products
	 * $acl->allow("*", "products", "browse");
	 *
	 * //Allow access to any role to browse on any resource
	 * $acl->allow("*", "*", "browse");
	 * </code>
	 */
	public function allow(string roleName, string resourceName, var access, var func = null)
	{
		var innerRoleName;

		if roleName != "*" {
			return this->_allowOrDeny(roleName, resourceName, access, Acl::ALLOW, func);
		} else {
			for innerRoleName, _ in this->_rolesNames {
				this->_allowOrDeny(innerRoleName, resourceName, access, Acl::ALLOW, func);
			}
		}
	}

	/**
	 * Deny access to a role on a resource
	 *
	 * You can use '*' as wildcard
	 *
	 * Example:
	 * <code>
	 * //Deny access to guests to search on customers
	 * $acl->deny("guests", "customers", "search");
	 *
	 * //Deny access to guests to search or create on customers
	 * $acl->deny("guests", "customers", ["search", "create"]);
	 *
	 * //Deny access to any role to browse on products
	 * $acl->deny("*", "products", "browse");
	 *
	 * //Deny access to any role to browse on any resource
	 * $acl->deny("*", "*", "browse");
	 * </code>
	 */
	public function deny(string roleName, string resourceName, var access, var func = null)
	{
		var innerRoleName;

		if roleName != "*" {
			return this->_allowordeny(roleName, resourceName, access, Acl::DENY, func);
		} else {
			for innerRoleName, _ in this->_rolesNames {
				this->_allowordeny(innerRoleName, resourceName, access, Acl::DENY, func);
			}
		}
	}

	/**
	 * Check whether a role is allowed to access an action from a resource
	 *
	 * <code>
	 * //Does andres have access to the customers resource to create?
	 * $acl->isAllowed("andres", "Products", "create");
	 *
	 * //Do guests have access to any resource to edit?
	 * $acl->isAllowed("guests", "*", "edit");
	 * </code>
	 *
	 * @param  RoleInterface|RoleAware|string roleName
	 * @param  ResourceInterface|ResourceAware|string resourceName
	 * @param  string access
	 * @param  array parameters
	 */
	public function isAllowed(var roleName, var resourceName, string access, array parameters = null) -> boolean
	{
		var eventsManager, accessList, accessKey,
			haveAccess = null, roleInherits, inheritedRole, rolesNames,
			funcAccess = null, resourceObject = null, roleObject = null, funcList,
			reflectionFunction, reflectionParameters, parameterNumber, parametersForFunction,
			numberOfRequiredParameters, userParametersSizeShouldBe, reflectionClass, parameterToCheck,
			reflectionParameter, hasRole = false, hasResource = false;

		if typeof roleName == "object" {
			if roleName instanceof RoleAware {
				let roleObject = roleName;
				let roleName = roleObject->getRoleName();
			} elseif roleName instanceof RoleInterface {
				let roleName = roleName->getName();
			} else {
				throw new Exception("Object passed as roleName must implement Phalcon\\Acl\\RoleAware or Phalcon\\Acl\\RoleInterface");
			}
		}

		if typeof resourceName == "object" {
			if resourceName instanceof ResourceAware {
				let resourceObject = resourceName;
				let resourceName = resourceObject->getResourceName();
			} elseif resourceName instanceof ResourceInterface {
				let resourceName = resourceName->getName();
			} else {
				throw new Exception("Object passed as resourceName must implement Phalcon\\Acl\\ResourceAware or Phalcon\\Acl\\ResourceInterface");
			}

		}

		let this->_activeRole = roleName;
		let this->_activeResource = resourceName;
		let this->_activeAccess = access;
		let accessList = this->_access;
		let eventsManager = <EventsManager> this->_eventsManager;
		let funcList = this->_func;

		if typeof eventsManager == "object" {
			if eventsManager->fire("acl:beforeCheckAccess", this) === false {
				return false;
			}
		}

		/**
		 * Check if the role exists
		 */
		let rolesNames = this->_rolesNames;
		if !isset rolesNames[roleName] {
			return (this->_defaultAccess == Acl::ALLOW);
		}

		/**
		 * Check if there is a direct combination for role-resource-access
		 */
		let accessKey = this->_isAllowed(roleName, resourceName, access);

		if accessKey != false && isset accessList[accessKey] {
			let haveAccess = accessList[accessKey];
			fetch funcAccess, funcList[accessKey];
		}

		/**
		 * Check in the inherits roles
		 */


		let this->_accessGranted = haveAccess;
		if typeof eventsManager == "object" {
			eventsManager->fire("acl:afterCheckAccess", this);
		}

		if haveAccess == null {
			return this->_defaultAccess == Acl::ALLOW;
		}

		/**
		 * If we have funcAccess then do all the checks for it
		 */
		if is_callable(funcAccess) {
			let reflectionFunction = new \ReflectionFunction(funcAccess);
			let reflectionParameters = reflectionFunction->getParameters();
			let parameterNumber = count(reflectionParameters);

			// No parameters, just return haveAccess and call function without array
			if parameterNumber === 0 {
				return haveAccess == Acl::ALLOW && call_user_func(funcAccess);
			}

			let parametersForFunction = [];
			let numberOfRequiredParameters = reflectionFunction->getNumberOfRequiredParameters();
			let userParametersSizeShouldBe = parameterNumber;

			for reflectionParameter in reflectionParameters {
				let reflectionClass = reflectionParameter->getClass();
				let parameterToCheck = reflectionParameter->getName();

				if reflectionClass !== null {
					// roleObject is this class
					if roleObject !== null && reflectionClass->isInstance(roleObject) && !hasRole {
						let hasRole = true;
						let parametersForFunction[] = roleObject;
						let userParametersSizeShouldBe--;

						continue;
					}

					// resourceObject is this class
					if resourceObject !== null && reflectionClass->isInstance(resourceObject) && !hasResource {
						let hasResource = true;
						let parametersForFunction[] = resourceObject;
						let userParametersSizeShouldBe--;

						continue;
					}

					// This is some user defined class, check if his parameter is instance of it
					if isset parameters[parameterToCheck] && typeof parameters[parameterToCheck] == "object" && !reflectionClass->isInstance(parameters[parameterToCheck]) {
						throw new Exception(
							"Your passed parameter doesn't have the same class as the parameter in defined function when check " . roleName . " can " . access . " " . resourceName . ". Class passed: " . get_class(parameters[parameterToCheck])." , Class in defined function: " . reflectionClass->getName() . "."
						);
					}
				}

				if isset parameters[parameterToCheck] {
					// We can't check type of ReflectionParameter in PHP 5.x so we just add it as it is
					let parametersForFunction[] = parameters[parameterToCheck];
				}
			}

			if count(parameters) > userParametersSizeShouldBe {
				trigger_error(
					"Number of parameters in array is higher than the number of parameters in defined function when check " . roleName . " can " . access . " " . resourceName . ". Remember that more parameters than defined in function will be ignored.",
					E_USER_WARNING
				);
			}

			// We dont have any parameters so check default action
			if count(parametersForFunction) == 0 {
				if numberOfRequiredParameters > 0 {
					trigger_error(
						"You didn't provide any parameters when check " . roleName . " can " . access . " "  . resourceName . ". We will use default action when no arguments."
					);

					return haveAccess == Acl::ALLOW && this->_noArgumentsDefaultAction == Acl::ALLOW;
				}

				// Number of required parameters == 0 so call funcAccess without any arguments
				return haveAccess == Acl::ALLOW && call_user_func(funcAccess);
			}

			// Check necessary parameters
			if count(parametersForFunction) >= numberOfRequiredParameters {
				return haveAccess == Acl::ALLOW && call_user_func_array(funcAccess, parametersForFunction);
			}

			// We don't have enough parameters
			throw new Exception(
				"You didn't provide all necessary parameters for defined function when check " . roleName . " can " . access . " " . resourceName
			);
		}

		return haveAccess == Acl::ALLOW;
	}

	/**
	 * Check whether a role is allowed to access an action from a resource
	 */
	protected function _isAllowed(string roleName, string resourceName, string access) -> string | boolean
    {
        var accessList, accessKey,checkRoleToInherit, checkRoleToInherits, usedRoleToInherits, usedRoleToInherit;

		let accessList = this->_access;

        let accessKey = roleName . "!" . resourceName . "!" . access;

		/**
		 * Check if there is a direct combination for role-resource-access
		 */
		if isset accessList[accessKey] {
			return accessKey;
		}
		/**
         * Check if there is a direct combination for role-*-*
         */
        let accessKey = roleName . "!" . resourceName . "!*";
        if isset accessList[accessKey] {
            return accessKey;
        }
        /**
         * Check if there is a direct combination for role-*-*
         */
        let accessKey = roleName . "!*!*";
        if isset accessList[accessKey] {
            return accessKey;
        }
        /**
         * Deep check if the role to inherit is valid
         */
        if isset this->_roleInherits[roleName] {
            let checkRoleToInherits = [];
            for usedRoleToInherit in this->_roleInherits[roleName] {
                let checkRoleToInherits[] = usedRoleToInherit;
            }
            let usedRoleToInherits = [];
            while !empty checkRoleToInherits {
                let checkRoleToInherit = array_shift(checkRoleToInherits);

                if isset usedRoleToInherits[checkRoleToInherit] {
                    continue;
                }
                let usedRoleToInherits[checkRoleToInherit] = true;

                let accessKey = checkRoleToInherit . "!" . resourceName . "!" . access;
                /**
                 * Check if there is a direct combination in one of the inherited roles
                 */
                if isset accessList[accessKey] {
                    return accessKey;
                }
                /**
                 * Check if there is a direct combination for role-*-*
                 */
                let accessKey = checkRoleToInherit . "!" . resourceName . "!*";
                if isset accessList[accessKey] {
                    return accessKey;
                }
                /**
                 * Check if there is a direct combination for role-*-*
                 */
                let accessKey = checkRoleToInherit . "!*!*";
                if isset accessList[accessKey] {
                    return accessKey;
                }
                /**
                 * Push inherited roles
                 */
                if isset this->_roleInherits[checkRoleToInherit] {
                    for usedRoleToInherit in this->_roleInherits[checkRoleToInherit] {
                        let checkRoleToInherits[] = usedRoleToInherit;
                    }
                }
            }
        }
        return false;
    }

	/**
	 * Sets the default access level (Phalcon\Acl::ALLOW or Phalcon\Acl::DENY)
	 * for no arguments provided in isAllowed action if there exists func for
	 * accessKey
	 */
	public function setNoArgumentsDefaultAction(int defaultAccess)
	{
		let this->_noArgumentsDefaultAction = defaultAccess;
	}

	/**
	 * Returns the default ACL access level for no arguments provided in
	 * isAllowed action if there exists func for accessKey
	 */
	public function getNoArgumentsDefaultAction() -> int
	{
		return this->_noArgumentsDefaultAction;
	}

	/**
	 * Return an array with every role registered in the list
	 */
	public function getRoles() -> <RoleInterface[]>
	{
		return this->_roles;
	}

	/**
	 * Return an array with every resource registered in the list
	 */
	public function getResources() -> <ResourceInterface[]>
	{
		return this->_resources;
	}
}
