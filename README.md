# Doclet

This is a custom Doclet that generates JSON files based on Javadoc comments in `.java` files. These JSON files have all the information necessary for building the reference pages on [processing.org](https://processing.org).

The Doclet will run through the `.java` file in the following repositories:

- [`processing/processing4`](https://github.com/processing/processing4)
- [`processing/processing-sound`](https://github.com/processing/processing-sound)
- [`processing/processing-video`](https://github.com/processing/processing-video)

It will read the JavaDoc comments, create a series of `.json` files, and save them into the Processing website repository in the `content/references/translations/en/` folder:

- [`processing/processing-website`](https://github.com/processing/processing-website)

You will need a local copy of at least one of `processing/processing4`, `processing/processing-sound` or `processing/processing-video` alongside the `processing/processing-website` repo. The repositories need to be alongside each other in the same folder.

## How to use

First, make sure that you have the proper setup before running the script:

### Get set up

1. If this is your first time, clone fresh versions of the following repositories alongside each other in the same folder:
   - [`processing/processing4`](https://github.com/processing/processing4)
   - [`processing/processing-sound`](https://github.com/processing/processing-sound)
   - [`processing/processing-video`](https://github.com/processing/processing-video)
   - [`processing/processing-website`](https://github.com/processing/processing-website)
   
If you already have those repositories cloned locally, just make sure that the latest commit of the `main` branch is checked out on all of them.

2. Make sure you have openjdk 17 installed and set the `JAVA_HOME` environment variable to point to the JDK installation. For example: `/Users/yourName/Library/Java/JavaVirtualMachines/corretto-17.0.4.1/Contents/Home`

Running `java -version` should return the following:

```
openjdk version "17.0.4.1" 2022-08-12 LTS
OpenJDK Runtime Environment Corretto-17.0.4.9.1 (build 17.0.4.1+9-LTS)
OpenJDK 64-Bit Server VM Corretto-17.0.4.9.1 (build 17.0.4.1+9-LTS, mixed mode, sharing)
```

_Note that the name of the JDK file may vary slightly depending on your exact version._

3. Install the latest version of [Apache Ant](https://ant.apache.org/manual/install.html) (1.10.13 or above).

4. Build the code for [`processing/processing4`](https://github.com/processing/processing4) and [`processing/processing-sound`](https://github.com/processing/processing-sound) by following the instructions on their respective repositories and running the necessary Ant commands.

### Run the doclet script

Now you are ready to run the doclet:

1. `cd` into the `processing-doclet/ReferenceGenerator` folder.
2. Run `ant compile`.
3. Run `./processingrefBuild.sh` if you are updating all the repositories or `./processingrefBuild.sh processing`, `./processingrefBuild.sh sound` or `./processingrefBuild.sh video` if you are updating a single repository.
4. After the new JSON files are created, move into `processing-website` and run `npx prettier --write content/references` to format the JSON files.

### Update the website

Follow the instructions over on the [`processing/processing-website`](https://github.com/processing/processing-website) repository to make a pull request for the newly updated reference files.

## Testing the script
If you just want to test the Doclet without the `processing-website` repo, you can create the following folder structure in the root folder

`processing-website/content/references/translations/en/`

Then run the doclet script normally and it will generate the JSON files in the folder above.
