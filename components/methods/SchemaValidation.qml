pragma Singleton
import QtQuick
import Quickshell.Io

import qs.config
import qs.services

QtObject {
  id: jsonUtils

  function validateAgainstSchema(value, schema, path = '') {
    const errors = [];
    _validate(value, schema, path, errors);

    if (errors.length > 0) {
      console.error("Validation Failed with errors:");
      errors.forEach(err => console.error("  - " + err));
      return false;
    }
    return true;
  }

  function _validate(value, schema, path, errors) {
    if (!schema)
      return;

    if (schema.$ref) {
      const refPath = schema.$ref.replace('#/definitions/', '');
      if (ConfigManager._configSchema && ConfigManager._configSchema.definitions && ConfigManager._configSchema.definitions[refPath]) {
        schema = ConfigManager._configSchema.definitions[refPath];
      }
    }

    if (schema.type) {
      if (!_validateType(value, schema.type, path, errors)) {
        return;
      }
    }

    if (schema.oneOf) {
      _validateOneOf(value, schema.oneOf, path, errors);
      return;
    }

    if (schema.enum && !schema.enum.includes(value)) {
      errors.push(`${path}: value "${value}" not in allowed values [${schema.enum.join(', ')}]`);
    }

    if (schema.minimum !== undefined && value < schema.minimum) {
      errors.push(`${path}: value ${value} is less than minimum ${schema.minimum}`);
    }
    if (schema.maximum !== undefined && value > schema.maximum) {
      errors.push(`${path}: value ${value} is greater than maximum ${schema.maximum}`);
    }

    if (schema.exclusiveMinimum !== undefined && value <= schema.exclusiveMinimum) {
      errors.push(`${path}: value ${value} must be greater than ${schema.exclusiveMinimum}`);
    }
    if (schema.exclusiveMaximum !== undefined && value >= schema.exclusiveMaximum) {
      errors.push(`${path}: value ${value} must be less than ${schema.exclusiveMaximum}`);
    }

    if (schema.pattern && typeof value === 'string') {
      const regex = new RegExp(schema.pattern);
      if (!regex.test(value)) {
        errors.push(`${path}: value "${value}" does not match pattern ${schema.pattern}`);
      }
    }

    if (schema.type === 'object' && typeof value === 'object' && value !== null) {
      _validateObject(value, schema, path, errors);
    }

    if (schema.type === 'array' && Array.isArray(value)) {
      _validateArray(value, schema, path, errors);
    }
  }

  function _validateType(value, expectedType, path, errors) {
    const actualType = Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value;

    if (expectedType === 'integer') {
      if (!Number.isInteger(value)) {
        errors.push(`${path}: expected integer, got ${typeof value}`);
        return false;
      }
    } else if (expectedType === 'array') {
      if (!Array.isArray(value)) {
        errors.push(`${path}: expected array, got ${actualType}`);
        return false;
      }
    } else if (expectedType === 'object') {
      if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        errors.push(`${path}: expected object, got ${actualType}`);
        return false;
      }
    } else if (actualType !== expectedType) {
      errors.push(`${path}: expected ${expectedType}, got ${actualType}`);
      return false;
    }

    return true;
  }

  function _validateObject(value, schema, path, errors) {
    if (schema.required) {
      schema.required.forEach(requiredProp => {
        if (!(requiredProp in value)) {
          errors.push(`${path ? path + '.' : ''}${requiredProp}: required field missing`);
        }
      });
    }

    if (schema.properties) {
      Object.keys(value).forEach(key => {
        const propSchema = schema.properties[key];
        if (propSchema) {
          const propPath = path ? `${path}.${key}` : key;
          _validate(value[key], propSchema, propPath, errors);
        }
      });
    }

    if (schema.additionalProperties !== undefined) {
      const definedProps = Object.keys(schema.properties || {});
      Object.keys(value).forEach(key => {
        if (!definedProps.includes(key)) {
          if (schema.additionalProperties === false) {
            errors.push(`${path}.${key}: additional property not allowed`);
          } else if (typeof schema.additionalProperties === 'object') {
            const propPath = path ? `${path}.${key}` : key;
            _validate(value[key], schema.additionalProperties, propPath, errors);
          }
        }
      });
    }

    if (schema.patternProperties) {
      Object.keys(value).forEach(key => {
        Object.entries(schema.patternProperties).forEach(([pattern, propSchema]) => {
          const regex = new RegExp(pattern);
          if (regex.test(key)) {
            const propPath = path ? `${path}.${key}` : key;
            _validate(value[key], propSchema, propPath, errors);
          }
        });
      });
    }
  }

  function _validateArray(value, schema, path, errors) {
    if (schema.items) {
      value.forEach((item, index) => {
        const itemPath = `${path}[${index}]`;
        _validate(item, schema.items, itemPath, errors);
      });
    }

    if (schema.minItems !== undefined && value.length < schema.minItems) {
      errors.push(`${path}: array has ${value.length} items, minimum is ${schema.minItems}`);
    }
    if (schema.maxItems !== undefined && value.length > schema.maxItems) {
      errors.push(`${path}: array has ${value.length} items, maximum is ${schema.maxItems}`);
    }
  }

  function _validateOneOf(value, oneOfSchemas, path, errors) {
    const matchingSchemas = [];

    for (let i = 0; i < oneOfSchemas.length; i++) {
      const subErrors = [];
      const subSchema = oneOfSchemas[i];

      // Resolve $ref if present
      let resolvedSchema = subSchema;
      if (subSchema.$ref) {
        const refPath = subSchema.$ref.replace('#/definitions/', '');
        if (ConfigManager._configSchema?.definitions[refPath]) {
          resolvedSchema = ConfigManager._configSchema.definitions[refPath];
        }
      }

      if (resolvedSchema.properties?.type?.const !== undefined) {
        if (value.type !== resolvedSchema.properties.type.const) {
          continue;
        }
      }

      _validate(value, resolvedSchema, path, subErrors);

      if (subErrors.length === 0) {
        matchingSchemas.push(i);
      }
    }

    if (matchingSchemas.length === 0) {
      errors.push(`${path}: value does not match any schema in oneOf`);
    } else if (matchingSchemas.length > 1) {
      errors.push(`${path}: value matches multiple schemas in oneOf (indices: ${matchingSchemas.join(', ')})`);
    }
  }

  function getSchemaProperty(schema, path) {
    const parts = path.split('.');
    let current = schema;

    for (const part of parts) {
      if (current.properties && current.properties[part]) {
        current = current.properties[part];
      } else {
        return null;
      }
    }
    return current;
  }
}
