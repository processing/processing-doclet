import com.sun.source.doctree.DocCommentTree;
import com.sun.source.util.DocTrees;
import java.io.IOException;
import java.lang.ProcessBuilder.Redirect.Type;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.ElementKind;
import javax.lang.model.element.ExecutableElement;
import javax.lang.model.element.PackageElement;
import javax.lang.model.element.TypeElement;
import javax.lang.model.element.VariableElement;
import javax.lang.model.type.TypeKind;
import javax.lang.model.util.ElementFilter;
import javax.tools.Diagnostic.Kind;
import jdk.javadoc.doclet.Doclet;
import jdk.javadoc.doclet.DocletEnvironment;
import jdk.javadoc.doclet.Reporter;
import jdk.javadoc.doclet.StandardDoclet;
import writers.ClassWriter;
import writers.FieldWriter;
import writers.FunctionWriter;
import writers.LibraryWriter;
import writers.Shared;

/*
 * @author David Wicks
 * Translated by Fernando Florenzano
 * ProcessingWeblet generates the web reference for processing.org and download
 * The source code of processing is parsed for webref tags to determine what gets included
 */
public class ProcessingWeblet extends StandardDoclet {

  private static final boolean OK = true;

  private static String examplesFlag = "-examplesdir";
  private static String templateFlag = "-templatedir";
  private static String outputFlag = "-webref";
  private static String exceptionsFlag = "-includedir";
  private static String imagesFlag = "-imagedir";
  private static String localFlag = "-localref";
  private static String coreFlag = "-corepackage"; //to allow for exceptions like XML being in the core
  private static String verboseFlag = "-noisy";
  private static String rootFlag = "-rootclass";
  private static String xmlDescriptionFlag = "-includeXMLTag";

  abstract class Option implements Doclet.Option {

    private final String name;
    private final boolean hasArg;
    private final String description;
    private final String parameters;

    Option(String name, boolean hasArg, String description, String parameters) {
      this.name = name;
      this.hasArg = hasArg;
      this.description = description;
      this.parameters = parameters;
    }

    @Override
    public int getArgumentCount() {
      return hasArg ? 1 : 0;
    }

    @Override
    public String getDescription() {
      return description;
    }

    @Override
    public Kind getKind() {
      return Kind.STANDARD;
    }

    @Override
    public List<String> getNames() {
      return List.of(name);
    }

    @Override
    public String getParameters() {
      return hasArg ? parameters : "";
    }
  }

  private final Set<Option> options = Set.of(
    new Option(
      templateFlag,
      true,
      "Where to find the html templates for output",
      "<string>"
    ) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setTemplateDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(
      examplesFlag,
      true,
      "Where to find the xml describing the examples to go in the reference",
      "<string>"
    ) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setExampleDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(
      outputFlag,
      true,
      "The local reference output directory",
      "<string>"
    ) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setOutputDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(
      exceptionsFlag,
      true,
      "Where to find things that aren't in the source, but only in xml e.g. [] (arrayaccess)",
      "<string>"
    ) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setIncludeDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(imagesFlag, true, "an option", "<string>") {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setImageDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(localFlag, true, "an option", "<string>") {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setLocalOutputDirectory(arguments.get(0));
        return OK;
      }
    },
    new Option(
      coreFlag,
      true,
      "Pass in as many of these as necessary to have things considered as part of the core (not a library) e.g -corepackage processing.xml",
      "<string>"
    ) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().corePackages.add(arguments.get(0));
        return OK;
      }
    },
    new Option(verboseFlag, false, "an option", null) {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().setNoisy(true);
        return OK;
      }
    },
    new Option(rootFlag, true, "an option", "<string>") {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().rootClasses.add(arguments.get(0));
        return OK;
      }
    },
    new Option(xmlDescriptionFlag, true, "an option", "<string>") {
      @Override
      public boolean process(String option, List<String> arguments) {
        Shared.i().addDescriptionTag(arguments.get(0));
        return OK;
      }
    }
  );

  Reporter reporter;

  @Override
  public void init(Locale locale, Reporter reporter) {
    reporter.print(Kind.NOTE, "Doclet using locale: " + locale);
    this.reporter = reporter;
  }

  @Override
  public String getName() {
    return getClass().getSimpleName();
  }

  @Override
  public Set<? extends Option> getSupportedOptions() {
    return options;
  }

  @Override
  public SourceVersion getSupportedSourceVersion() {
    return SourceVersion.latest();
  }

  @Override
  public boolean run(DocletEnvironment environment) {
    Shared.i().corePackages.add("processing.core");
    Shared.i().rootClasses.add("processing.core.PApplet");
    Shared.i().rootClasses.add("processing.core.PConstants");

    Shared.i().setUtils(environment);

    Shared.i().createBaseDirectories();

    try {
      // write out everything in the .java files:
      // Classes, Methods, Fields ... see specific XxxWriters

      System.out.println("\n===Writing .javadoc sourced reference.===");

      writeContents(environment);

      System.out.println("===Source code @webref files written.===");
    } catch (IOException e) {
      // TODO Auto-generated catch block
      e.printStackTrace();
    }

    System.out.println("===All finished in the weblet.===");

    return OK;
  }

  private static void writeContents(DocletEnvironment environment)
    throws IOException {
    System.out.println("Write contents: ");

    for (Element element : environment.getIncludedElements()) {
      if (!Shared.i().isClassOrInterface(element)) {
        continue;
      }

      TypeElement classElement = (TypeElement) element;

      System.out.println("\nElement: " + classElement);

      if (Shared.i().isCore(classElement)) {
        // Document the core functions and classes
        if (Shared.i().isRootLevel(classElement)) {
          // if it is in PApplet, PConstants or other classes where users can get
          // the variables without using dot syntax

          for (Element subElement : element.getEnclosedElements()) {
            // document functions
            if (Shared.i().isMethod(subElement)) {
              ExecutableElement methodElement = (ExecutableElement) subElement;

              System.out.println("method!: " + methodElement);

              FunctionWriter.write(methodElement);
            }
            // also need to add fields
            if (Shared.i().isField(subElement)) {
              VariableElement fieldElement = (VariableElement) subElement;

              System.out.println("field!: " + fieldElement);

              if (Shared.i().isWebref(fieldElement)) {
                FieldWriter.write(fieldElement);
              }
            }
          }
        } else {
          // document a class and its public properties
          System.out.println("class!: " + classElement);
          new ClassWriter().write(classElement);
        }
      } else {
        // Document the library passed in
        if (Shared.i().isNoisy()) {
          System.out.println("Loaded class: " + classElement.toString());
        }

        PackageElement packageElement = Shared
          .i()
          .getContainingPackage(classElement);

        if (packageElement == null) {
          continue;
        }

        // System.out.println(
        //   "ok lets see this parent " +
        //   packageElement +
        //   " " +
        //   packageElement.getKind()
        // );

        LibraryWriter writer = new LibraryWriter();
        writer.write(packageElement);
      }
    }
  }
}
