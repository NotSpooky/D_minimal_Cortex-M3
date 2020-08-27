// start.d

// These are marked extern(C) to avoid name mangling, so we can refer to them in our linker script
// Alias Interrupt Service Routine function pointers
alias void function () ISR;
// Pointer to entry point, OnReset
extern (C) immutable ISR resetHandler = & onReset;

enum semihostingOperation : int {
  open = 1, close = 2, writeChar = 3, writeCStr = 4, write = 5, read = 6
  , readChar = 7, isError = 8, isTTy = 9, seek = 10, fileLength = 12
  , tempFilePath = 13, removeFile = 14, renameFile = 15, clock = 16
  , time = 17, errno = 19, getCmdLine = 21, heapInfo = 22, elapsed = 48
  , tickFreq = 49
}

void semihostingMsg (string toSend, uint stream = 2 /* stderr */) {
  int command = semihostingOperation.write;
  uint [3] message = [stream, cast (uint) toSend.ptr, toSend.length];
  auto msgPtr = &message;
  // LDC and GDC use slightly different inline assembly syntax, so we have to 
  // differentiate them with D's conditional compilation feature, version.
  version (LDC) {
    import ldc.llvmasm;
    __asm (
      "mov r0, $0;
      mov r1, $1;
      bkpt #0xAB" // SVC number
      , "r,r,~{r0},~{r1}"
      , command, msgPtr
    );
  } else version (GNU) {
    asm
    {
      "mov r0, %[cmd]; 
       mov r1, %[msg]; 
       bkpt #0xAB" // SVC number
        :                              
        : [cmd] "r" command, [msg] "r" msgPtr
        : "r0", "r1", "memory";
    }
  }
}

// TODO: Test ok
int semihostingReadChar () {
  import ldc.llvmasm;
  return __asm!int (
    "mov r0, $1;
    mov r1, #0;
    bkpt #0xAB;
    mov $0, r1"
    , "=r,r,~{r0},~{r1}"
    , semihostingOperation.readChar
  );
}

enum PERIPH_BASE = 1073741824;
enum APB2PERIPH_BASE = PERIPH_BASE + 65536;
enum AHBPERIPH_BASE = PERIPH_BASE + 131072;
enum RCC = AHBPERIPH_BASE + 4096;
enum GPIOC = APB2PERIPH_BASE + 4096;
enum RCC_APB2ENR_IOPCEN = 16;
enum GPIO_CRH_MODE13 = 3145728;
enum GPIO_CRH_CNF13 = 12582912;
enum GPIO_CRH_MODE13_0 = 1048576;
enum GPIO_CRH_MODE13_1 = 2097152;
enum GPIO_BSRR_BR13 = 536870912;
enum GPIO_BSRR_BS13 = 8192;
struct RCC_TypeDef {
  uint CR;
  uint CFGR;
  uint CIR;
  uint APB2RSTR;
  uint APB1RSTR;
  uint AHBENR;
  uint APB2ENR;
  uint APB1ENR;
  uint BDCR;
  uint CSR;
}

struct GPIO_TypeDef {
  uint CRL;
  uint CRH;
  uint IDR;
  uint ODR;
  uint BSRR;
  uint BRR;
  uint LCKR;
}

struct GPIOPin {
  void set () {
    (cast (GPIO_TypeDef *) GPIOC).BSRR = GPIO_BSRR_BS13;
  }
  void reset () {
    (cast (GPIO_TypeDef *) GPIOC).BSRR = GPIO_BSRR_BR13;
  }
}
struct APB2 {
  auto initPin (uint pinN)() {
    import std.conv;
    enum pinNStr = pinN.to!string;
    enum crhMode = mixin (`GPIO_CRH_MODE` ~ pinNStr);
    enum crhCnf = mixin (`GPIO_CRH_CNF` ~ pinNStr);
    (cast (GPIO_TypeDef *) GPIOC).CRH &= ~(crhMode | crhCnf); // reset
    enum crhMode_0 = mixin (`GPIO_CRH_MODE` ~ pinNStr ~ `_0`);
    enum crhMode_1 = mixin (`GPIO_CRH_MODE` ~ pinNStr ~ `_1`);
    (cast (GPIO_TypeDef *) GPIOC).CRH |= (crhMode_0 | crhMode_1); // config
    return GPIOPin ();
  }
}
auto enableClock () {
  (cast (RCC_TypeDef *) RCC).APB2ENR |= RCC_APB2ENR_IOPCEN; // enable clock
  return APB2 ();
}

void ledOn () {
}

// The program's entry point
void onReset () {
  // text to display
  string onMsg = "ON\n";
  string offMsg = "OFF\n";
  auto ledPin = enableClock ().initPin!13 ();
  // run repeatedly
  while (true) {
    ledPin.reset (); // LED on - pin 13 is active low.
    semihostingMsg (onMsg);
    for (int i = 0; i <150000; i++) {}
    ledPin.set (); // LED off.
    semihostingMsg (offMsg);
    for (int i = 0; i <150000; i++) {}
    //ch = cast (char) semihostingReadChar ();
    //spooks = cast (string) (&ch) [0..1];
  }
}
