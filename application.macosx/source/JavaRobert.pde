import oscP5.*;
import netP5.*;
import controlP5.*;
import processing.serial.*;
import java.util.*;

Serial myPort;  // Create object from Serial class
int val;      // Data received from the serial port
int oldVal = 0;
boolean portOpen = false;

OscP5 oscP5;
NetAddress qLab;
NetAddress phone;

ControlP5 cp5;

final String[] listNames = {"fast", "medium","fixed", "knowledge"};
final int fast = 0;
final int medium = 1;
final int fixed = 2;
final int knowledge = 3;
final String[] players = {"Michael als Michael", "Michael als Christian", "Christian als Christian", "Christian als Michael"};
float[] playerProbability = {0.333,0.167,0.333,0.167};
int[] fixedPlayers = {3,2,1,0,2,0,2,0,2,2,0,0,0};
JSONArray sequencesJSON;

color green = color(0,255,0);
color red = color(255,0,0);
color serialControlColor = red;
boolean serialControl;
int serialControlTimer = 100;

int scene = 0;
int buzzCount;

class Questions {
  int count = -1;
  boolean shuffle = false;
  StringList questions;
  Questions (String name){
    JSONArray questionsJSON = loadJSONArray(name + ".json");
    int questionsJSONSize = questionsJSON.size();
    questions = new StringList(questionsJSONSize);
    for(int j = 0; j < questionsJSONSize; j++){
      questions.append(questionsJSON.getString(j));
    }
  }
  void shuffle() {
    questions.shuffle();
  }
  String getQuestion(){
    count++;
    if(count < questions.size()){
      return questions.get(count);
    } else return "";
  }
  void reset(){
    if(shuffle)this.shuffle();
    count = -1;
  }
}

Questions[] allQuestions = new Questions[listNames.length];

//***************** Reset ******************//

void reset() {
  for(int i=0; i<listNames.length; i++){
    allQuestions[i].reset();
  }
  fixedPlayers[2] = floor(random(players.length));
  buzzCount = 0;
  scene = 0;
  updatePlaybackController();
}

//***************** Setup ******************//

void setup() {
  size(400,400);
  frameRate(25);
  /* start oscP5, listening for incoming messages at port 8000 */
  oscP5 = new OscP5(this,8000);
  qLab = new NetAddress("127.0.0.1",53000);
  phone = new NetAddress("192.168.0.51",9000);
  
  sequencesJSON = loadJSONArray("sequences.json");
  
  for(int i=0; i<listNames.length; i++){
    allQuestions[i] = new Questions(listNames[i]);
    if(i<2 || i>2){
      allQuestions[i].shuffle();
      allQuestions[i].shuffle = true;
    }
  }
  
  for(int i=1;i<playerProbability.length;i++){
    playerProbability[i] += playerProbability[i-1];
  }
  
  //GUI
  
  noStroke();
  cp5 = new ControlP5(this);
  for (int i=0;i<3;i++) {
    cp5.addBang(listNames[i])
       .setPosition(20+i*80, 20)
       .setSize(40, 40)
       .setId(i)
       ;
  }
  cp5.addBang("buzzer")
       .setPosition(20+3*80, 20)
       .setSize(40, 40)
       .setId(3)
       ;
  cp5.addBang("reset")
       .setPosition(20+4*80, 20)
       .setSize(40, 40)
       .setId(4)
       ;    
  cp5.addTextfield("phoneIP")
     .setPosition(20,200)
     .setSize(200,20)
     .setFocus(true)
     .setColor(color(255,0,0))
     ;
  // Serial
  
  cp5.addScrollableList("dropdown")
     .setPosition(50, 140)
     .setSize(200, 100)
     .setBarHeight(20)
     .setItemHeight(20)
     .addItems(Serial.list())
     // .setType(ScrollableList.LIST) // currently supported DROPDOWN and LIST
     ;
}

//***************** Draw ******************//

void draw() {
  background(0);
  if(portOpen){
    if ( myPort.available() > 0) {
      serialControlTimer = 0;
      val = myPort.read();
      if(val == 1 && oldVal == 0){
        buzzer();
      }
      oldVal = val;
    }
    serialControlTimer++;
    serialControlColor = serialControlTimer > 25 * 1 ? red : green;
  } else {
    serialControlColor = red;
  }
  text(val, 260,155);
  fill(serialControlColor);
  ellipse(30,150,20,20);
  fill(255);
  text("Playback Position:",20, 100);
  text("Scene: " + scene + " Question: " + buzzCount,20, 120);
  text(phone.address(), 240, 215);
}

//***************** GUI Controller ******************//

public void controlEvent(ControlEvent theEvent) {
  if(theEvent.isAssignableFrom(Button.class)) {
    for (int i=0;i<3;i++) {
      if (theEvent.getController().getId() == i) {
        message(i);
      }
    }
    if (theEvent.getController().getName().equals("reset")){
      reset();
    }
  }
  if(theEvent.isAssignableFrom(Textfield.class)) {
    if (theEvent.getController().getName().equals("phoneIP")){
      String tempIP = theEvent.getStringValue();
      String[] matchIP = match(tempIP, "^(([01]?\\d\\d?|2[0-4]\\d|25[0-5])\\.){3}([01]?\\d\\d?|2[0-4]\\d|25[0-5])$");
      if(matchIP != null){
        phone = new NetAddress(tempIP,9000);
      }
    }
  }
}

void dropdown(int n) {
  String portName = Serial.list()[n];
  try{
    myPort = new Serial(this, portName, 115200);
    portOpen = true;
  } catch (RuntimeException e){
    println(e);
    portOpen = false;
  }
}

//*********** OSC Input *****************//

/* incoming osc message are forwarded to the oscEvent method. */
void oscEvent(OscMessage theOscMessage) {
  for(int mode=0; mode<3; mode++){
    if (theOscMessage.checkAddrPattern("/" + listNames[mode])==true){
      float state = theOscMessage.get(0).floatValue(); // get the first osc argument
      if (state == 1.0){
        message(mode);
      }
    }
  }
  if (theOscMessage.checkAddrPattern("/buzz")==true){
    float state = theOscMessage.get(0).floatValue(); // get the first osc argument
      if (state == 1.0){
        println("OSC-alarm");
        buzzer();
      }
  }else if (theOscMessage.checkAddrPattern("/reset")==true){
    float state = theOscMessage.get(0).floatValue(); // get the first osc argument
      if (state == 1.0){
        reset();
      }
  } else if (theOscMessage.checkAddrPattern("/black")==true){
    float state = theOscMessage.get(0).floatValue(); // get the first osc argument
      if (state == 1.0){
        black();
      }
  } else if (theOscMessage.checkAddrPattern("/scene")==true){
    scene = int(theOscMessage.get(0).floatValue()); // get the first osc argument
    buzzCount = 0;
    updatePlaybackController();
  }
}

//*********** Executor Functions *****************//

void message (int mode) {
  
    String messageString;
    if(mode == fast && allQuestions[knowledge].count<2 && random(10)<1){
      messageString = allQuestions[knowledge].getQuestion();
    } else {
      messageString = allQuestions[mode].getQuestion();
    }
  
    OscMessage myMessage = new OscMessage("/cue/T2/text");
    myMessage.add(messageString); /* add a string to the osc message */
    oscP5.send(myMessage, qLab);  /* send the message */
    
    myMessage = new OscMessage("/cue/T4/text");
    myMessage.add(messageString); /* add a string to the osc message */
    oscP5.send(myMessage, qLab);  /* send the message */
  
    String playerString;
    if(mode == fixed && allQuestions[fixed].count < fixedPlayers.length){
      playerString = players[fixedPlayers[allQuestions[mode].count]];
    } else {
      float playerProbabilityDecider = random(1);
      int playerChooser;
      println(playerProbabilityDecider);
      for(playerChooser = 0; playerProbabilityDecider > playerProbability[playerChooser]; playerChooser++){}
      println(playerChooser);
      playerString = players[playerChooser];
    }
    
    myMessage = new OscMessage("/cue/T1/text");
    myMessage.add(playerString); /* add a string to the osc message */
    oscP5.send(myMessage, qLab); /* send the message */
    
    myMessage = new OscMessage("/cue/T3/text");
    myMessage.add(playerString); /* add a string to the osc message */
    oscP5.send(myMessage, qLab); /* send the message */
    
    // start TextCues
    myMessage = new OscMessage("/cue/T0/start");
    oscP5.send(myMessage, qLab);
}

void buzzer () {
  JSONArray currentScene = sequencesJSON.getJSONArray(scene);
  if(buzzCount < currentScene.size()){
    int mode = currentScene.getInt(buzzCount);
    message(mode);
    buzzCount++;
  } else if (scene < sequencesJSON.size()){
    scene++;
    buzzCount = 0;
    buzzer();
  }
  
  updatePlaybackController();
}

void black(){
    // start TextCues
    OscMessage myMessage = new OscMessage("/cue/BLCK/start");
    oscP5.send(myMessage, qLab);
}

void updatePlaybackController () {
  OscMessage myMessage = new OscMessage("/scene");
  myMessage.add("Scene " + scene); /* add a string to the osc message */
  oscP5.send(myMessage, phone);
  
  myMessage = new OscMessage("/question");
  myMessage.add("Question " + buzzCount); /* add a string to the osc message */
  oscP5.send(myMessage, phone);
}
