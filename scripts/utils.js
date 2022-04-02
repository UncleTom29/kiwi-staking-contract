async function verify(name, address, args) {
  try {
    await hre.run('verify:verify', {
      address,
      constructorArguments: args,
    });
    console.log(`${name} verified`);
  } catch (err) {
    console.log(err);
  }
}

module.exports = { verify };
