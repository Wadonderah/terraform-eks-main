exports.handler = async (event) => {
  console.log("Lambda is running!", event);

  return {
    statusCode: 200,
    body: JSON.stringify({ message: "Lambda is working fine!" }),
  };
};
