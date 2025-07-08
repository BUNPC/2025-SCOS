#include <SPI.h>
#define DAC_MAX 16384
const int DAC0_PIN = 53;
const int DAC1_PIN = 14;
const int MCU_ENA_PIN = 13;

long interval = 10000;  // us
long cameraDelay = 2000;
long diffTime;

long galvo_start = 0;
long galvo_end = 6200;
long triggerDuration = 4000;
long slopeDuration = 1000;

//int x_0 = 9141;  // 0 to 4095, 2048 = 0 V; ch 5 (fiber to rest on / to inform the safety circuit)
//int y_0 = 9373;

//int x_0 = 11808;  // 0 to 4095, 2048 = 0 V; ch 5 (fiber to rest on / to inform the safety circuit)
//int y_0 = 9800;
int x_0 = 8956;  // 0 to 4095, 2048 = 0 V; ch 5 (fiber to rest on / to inform the safety circuit)
int y_0 = 9324;

unsigned long nextTime = micros();

//           1      2       3      4     10     11    12
//int x[] = { 11808, 11808, 11808, 11808, 11808, 11808, 11808 };  
//int y[] = { 9800, 9800, 9800, 9800, 9800, 9800, 9800 };

//int x[] = { 11808, 9008, 9008, 9008, 9008, 9008, 9008 };  
//int y[] = { 9800, 9417, 9417, 9417, 9417, 9417, 9417 };

//int x[] = { 9008, 9008, 9008, 9008, 9008, 9008, 9008 };  
//int y[] = { 9417, 9417, 9417, 9417, 9417, 9417, 9417 };

//int x[] = { 9008, 12746, 12746, 12746, 12746, 12746, 12746 };  
//int y[] = { 9417, 9916, 9916, 9916, 9916, 9916, 9916 };

int x[] = { 12656, 11751, 10829, 9909, 4357, 3402, 2486 };  // 1 2 3 4 10 11 12
int y[] = {  9839,  9697,  9574, 9449, 8687, 8558, 8441 };

uint16_t current_coor[2];

int currentCh = 0;
int max_ch;
const int cam_trig_pins[] = { 49, 48, 47, 46, 45, 44, 43, 42, 37, 36, 35, 34, 33, 32, 31, 30, 39 };
#define NUM_TRIG_PINS (sizeof(cam_trig_pins) / sizeof(cam_trig_pins[0]))

int frame = 0;
int firstTriggerGiven = 0;
int photodiode_safety = A1;
int photodiode_task = A0;
int value1;
int value2;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication at 9600 bits per second:
  max_ch = sizeof(x) / sizeof(int);
  max_ch = max_ch - 1;
  for (int i = 0; i < NUM_TRIG_PINS; i++) {
    pinMode(cam_trig_pins[i], OUTPUT);
    digitalWrite(cam_trig_pins[i], LOW);
  }
  pinMode(DAC0_PIN, OUTPUT);
  pinMode(DAC1_PIN, OUTPUT);
  pinMode(MCU_ENA_PIN, OUTPUT);
  digitalWrite(DAC0_PIN, HIGH);
  digitalWrite(DAC1_PIN, HIGH);
  digitalWrite(MCU_ENA_PIN, HIGH);
  pinMode(11, INPUT);
  SPI.begin();
  Serial.begin(115200);
}

void moveGalvos(uint16_t dac_coor[2]) {
  SPI.beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
  digitalWrite(DAC0_PIN, LOW);
  SPI.transfer16(dac_coor[0] << 2);
  // low 2 bits ignored
  digitalWrite(DAC0_PIN, HIGH);
  digitalWrite(DAC1_PIN, LOW);
  SPI.endTransaction();
  SPI.beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
  SPI.transfer16(dac_coor[1] << 2);
  digitalWrite(DAC1_PIN, HIGH);
  SPI.endTransaction();
}

// the loop routine runs over and over again forever:
void loop() {
  for (int i = 0; i < NUM_TRIG_PINS; i++) {
    pinMode(cam_trig_pins[i], OUTPUT);
    digitalWrite(cam_trig_pins[i], HIGH);
  }
  current_coor[0] = x_0;
  current_coor[1] = y_0;
  moveGalvos(current_coor);
  Serial.println("Press spacebar then enter to start the galvo movement.");
  WaitForSpace();
  Serial.println("Starting.");
  while (true) {
    frame += 1;

    unsigned long currentTime = micros();
    diffTime = currentTime - nextTime;

    if (firstTriggerGiven == 0) {
      currentCh = 0;
    }
    if ((diffTime >= galvo_start) & (diffTime <= galvo_start + slopeDuration)) {  // upward slope of trapezoid
      current_coor[0] = round((x[currentCh] - x_0) * diffTime / slopeDuration + x_0);
      current_coor[1] = round((y[currentCh] - y_0) * diffTime / slopeDuration + y_0);
      //Serial.println("Upward");
      //Serial.println(String(current_coor[0]));
      moveGalvos(current_coor);
    } else if ((diffTime > galvo_start + slopeDuration) & (diffTime <= galvo_end)) {  // high plateau of trapezoid
      current_coor[0] = x[currentCh];
      current_coor[1] = y[currentCh];
      //Serial.println("Plateau");
      //Serial.println(String(current_coor[0]));
      moveGalvos(current_coor);
    } else if ((diffTime >= galvo_end) & (diffTime <= galvo_end + slopeDuration)) {  // downward slope of trapezoid
      current_coor[0] = round(-(x[currentCh] - x_0) * (diffTime - galvo_end) / slopeDuration + x[currentCh]);
      current_coor[1] = round(-(y[currentCh] - y_0) * (diffTime - galvo_end) / slopeDuration + y[currentCh]);
      //Serial.println("Downward");
      //Serial.println(String(current_coor[0]));
      moveGalvos(current_coor);
    } else {  // bottom of trapezoid
      current_coor[0] = x_0;
      current_coor[1] = y_0;
      //Serial.println("Bottom");
      //Serial.println(String(current_coor[0]));
      moveGalvos(current_coor);
    }

    if ((diffTime >= cameraDelay) & (diffTime <= cameraDelay + triggerDuration)) {  // when trigger is given
      for (int i = 0; i < NUM_TRIG_PINS; i++) {
        pinMode(cam_trig_pins[i], OUTPUT);
        digitalWrite(cam_trig_pins[i], HIGH);
        firstTriggerGiven = 1;
      }
    } else {
      for (int i = 0; i < NUM_TRIG_PINS; i++) {
        pinMode(cam_trig_pins[i], OUTPUT);
        digitalWrite(cam_trig_pins[i], LOW);
      }
    }

    // check if it's time
    if (diffTime >= interval) {
      // update next time
      nextTime += interval;

      if (currentCh == max_ch) {
        currentCh = 0;
      } else {
        currentCh = currentCh + 1;
      }
    }

    // read
    //if (frame % 16 == 0) {
    //value1 = analogRead(photodiode_safety);
    //value2 = analogRead(photodiode_task);
    // print_uint64_t(currentTime);
    //Serial.print("," + String(value1) + "," + String(value2) + "\n");
    //}
  }
}

void WaitForSpace() {
  while (true) {
    if (Serial.available() > 0)
      if (Serial.read() == ' ')
        break;
  }
}

void print_uint64_t(uint64_t num) {

  char rev[128];
  char *p = rev + 1;

  while (num > 0) {
    *p++ = '0' + (num % 10);
    num /= 10;
  }
  p--;
  /*Print the number which is now in reverse*/
  while (p > rev) {
    Serial.print(*p--);
  }
}
