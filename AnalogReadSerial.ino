/*
  AnalogReadSerial
  Reads an analog input on pin 0, prints the result to the serial monitor.
  Graphical representation is available using serial plotter (Tools > Serial Plotter menu)
  Attach the center pin of a potentiometer to pin A0, and the outside pins to +5V and ground.

  This example code is in the public domain.
*/

int timer = 0;
int delayTime = 100;

// the setup routine runs once when you press reset:
void setup() {
  // initialize serial communication at 9600 bits per second:
  Serial.begin(115200);
  pinMode(4, INPUT);
  pinMode(13, OUTPUT);
  digitalWrite(4, INPUT_PULLUP);  // set pullup on digital pin 0
}

void loop() {
  if (digitalRead(4) == HIGH) {  // If switch is ON,
    Serial.write(0);               // send 1 to Processing
    digitalWrite(13, LOW); 
  } else {                               // If the switch is not ON,
    Serial.write(1);               // send 0 to Processing
    digitalWrite(13, HIGH);
  }
  delay(delayTime);
}
