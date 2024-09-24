#!/bin/bash

# Searches the current working directory for any files named *.properties and
# looks up values from parameter store. It only searches at the current level
# and does not descend into sub-directories.
#
# It looks for values in the properties like MY_VAR="@/chips/env/path/to/secret" and 
# replaces the path with the value held in parameter store (if it is available)

function processPropertyFile() {
  PROPERTIES_FILE=$1

  # Get list of param store paths from the properties file
  PATHS_TO_LOOKUP=$( grep "@/" ${PROPERTIES_FILE} | sed 's/.*["'\'']@\(\/.*\)["'\'']$/\1/g' )

  for PATH_TO_LOOKUP in ${PATHS_TO_LOOKUP}
  do
    echo "Looking up ${PATH_TO_LOOKUP} found in ${PROPERTIES_FILE}"
    VALUE=$( aws ssm get-parameter --with-decryption --region ${EC2_REGION} --output text --query Parameter.Value --name ${PATH_TO_LOOKUP} 2> /dev/null )
    EXIT_CODE=$?

    if [[ EXIT_CODE -eq 0 ]]; then
      ESCAPED_VALUE=$( printf '%s\n' "${VALUE}" | sed -e 's/[\/&]/\\&/g' )
      ESCAPED_PATH=$( printf '%s\n' "${PATH_TO_LOOKUP}" | sed -e 's/[]\/$*.^[]/\\&/g' )
      sed -i "s/@${ESCAPED_PATH}/${ESCAPED_VALUE}/g" ${PROPERTIES_FILE}
    elif [[ EXIT_CODE -eq 255 ]]; then
      echo "No value found for path ${PATH_TO_LOOKUP}"
    else
      echo "Error looking up path ${PATH_TO_LOOKUP}"
    fi
  done
}

for PROPERTY_FILE in *.properties
do
  if [[ -f ${PROPERTY_FILE} ]]; then
    processPropertyFile ${PROPERTY_FILE}
  fi
done
